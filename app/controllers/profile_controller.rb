class ProfileController < ApplicationController
    protect_from_forgery except: :sign_sd_dataprovider

    include ApplicationHelper
    include SessionsHelper

    require 'mail'
    require 'net/smtp'
    require 'net/protocol'

    before_action :logged_in_user, except: [:sigbox_success, :sigbox_failure]
    before_action :set_view

    def settings
        @user = User.find(current_user[:id]) rescue nil
        if @user.nil?
            log_out
            redirect_to start_path
            return
        end
        @firstname = @user.given_name
        @lastname = @user.last_name
        @bpk = @user.bpk
        @email = @user.email rescue nil
        @email_verified = @user.email_verified rescue nil
        @email_verified_at = @user.email_verified_at rescue nil
        @did = @user.did rescue ''
        @did_renew_at = Time.at(@user.did_valid_until).to_datetime rescue nil

        # QR code for wallet connection
        preauth_code = SecureRandom.urlsafe_base64(17)[0,22]
        @nonce = SecureRandom.alphanumeric(10)
        @complete_code = SecureRandom.alphanumeric(10)
        @session_id = preauth_code

        item = {}
        item["preauth-code"] = preauth_code
        item["nonce"] = @nonce
        item["complete-code"] = @complete_code
        item["ida_user"] = @user.bpk
        item["ida_given_name"] = @user.given_name
        item["ida_family_name"] = @user.last_name
        item["ida_auth_time"] = @user.ida_auth_time

        @store = Store.new
        @store.item = item
        @store.key = preauth_code
        @store.save

        issuer_host = ENV['ISSUER_HOST'] || ISSUER_HOST
        payload = {
            credential_issuer: issuer_host + CREDENTIAL_DID_PATH,
            credential_configuration_ids: ["DID_FlexCo"],
            grants: {
                "urn:ietf:params:oauth:grant-type:pre-authorized_code":{
                    "pre-authorized_code": preauth_code,
                    "user_pin_required": false
                }
            }
        }
        @credential_offer = "openid-credential-offer://?credential_offer=" +
            URI.encode_www_form_component(payload.to_json)

    end

    def email_update
        email = params.require(:email)
        unless valid_email?(email)
            redirect_to settings_path, 
                alert: t('admin.messages.invalid_email') and return
        end

        token = SecureRandom.urlsafe_base64(32)
        verification_link = "https://#{ENV.fetch('RAILS_CONFIG_HOSTS')}/verify?token=#{token}"
        @user = User.find(current_user[:id])
        if @user.nil?
            flash[:error] = I18n.t('admin.messages.email_error')
            redirect_to settings_path
            return
        end
        @user.email = email
        @user.email_verification_token = token
        @user.email_verification_expires_at = DateTime.now+24.hours
        @user.save

        subject   = I18n.t('mailers.user_mailer.email_verification.subject')
        text_body = I18n.t('mailers.user_mailer.email_verification.body_text', 
                         name: current_user[:full_name],
                         email: email,
                         link: verification_link)
        html_body = I18n.t('mailers.user_mailer.email_verification.body_html', 
                         name: current_user[:full_name],
                         email: email,
                         link: verification_link)

        mail = Mail.new
        mail.from         = "no-reply@ownyourdata.eu"
        mail.to           = email
        mail.subject      = subject
        mail.content_type = 'multipart/alternative'
        mail.text_part    = Mail::Part.new { content_type 'text/plain; charset=UTF-8'; body text_body }
        mail.html_part    = Mail::Part.new { content_type 'text/html; charset=UTF-8'; body html_body }

        event_object = {
            email: email,
            verification_link: verification_link, 
            user_id: @user.id,
            verification_expires_at: @user.email_verification_expires_at,
            text_body: text_body
        }
        createEvent(
            bpk: current_user[:bpk], 
            event_str: 'send_email_verification', 
            event_object: event_object )


        method   = ActionMailer::Base.delivery_method
        settings = ActionMailer::Base.public_send("#{method}_settings")
        mail.delivery_method(method, settings)
        mail.deliver!
        
        redirect_to settings_path, 
            notice: t('admin.messages.email_sent')

    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
        Rails.logger.error("Email update failed (DB): #{e.class} - #{e.message}")
        redirect_to settings_path, 
            alert: t('admin.messages.email_error')

    rescue Net::SMTPFatalError, Net::OpenTimeout, IOError, SocketError, Mail::Field::ParseError => e
        Rails.logger.error("Email sending failed: #{e.class} - #{e.message}")
        redirect_to settings_path, 
            alert: t('admin.messages.email_error')
    rescue => e
        Rails.logger.error("email_update failed: #{e.class} - #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        redirect_to settings_path, 
            alert: t('admin.messages.email_error')
    end

    def sign_sd_dataprovider
        payload = JSON.parse(params[:payload]) rescue {}
        meta = JSON.parse(params[:meta]) rescue {}

        form_url = 'https://soya-form.ownyourdata.eu/?viewMode=form-only' +
            '&schemaDri=' + meta['schema'].to_s + 
            '&tag=basic&language=' + meta['language'].to_s + 
            '&data=' + CGI.escape(payload.to_json)
        base_url = form_url.match(%r{^https?://[^/]+}).to_s

        browser = Ferrum::Browser.new(
          browser_path: "/usr/bin/chromium",
          process_timeout: 30,
          timeout: 60,
          browser_options: {
            'no-sandbox': nil,
            'disable-gpu': nil
          })
        browser.go_to(form_url)

        timeout = 15
        start_time = Time.now

        loop do
          el = browser.at_css('div.MuiCardHeader-content span.MuiTypography-h5')
          if el && el.text.include?("i") # irgendein Text!
            puts "✅ Formular vollständig gerendert!"
            break
          end
          if Time.now - start_time > timeout
            browser.screenshot(path: "/tmp/soya_form_timeout.png", full: true)
            raise "❌ Timeout: Formular wurde nach #{timeout}s nicht geladen (Screenshot gespeichert)"
          end
          sleep 0.5
        end

        html = browser.body

        pdf_binary = WickedPdf.new.pdf_from_string(
            html,
            encoding: 'UTF-8',
            page_size: 'A4',
            print_media_type: true,
            margin: { top: 10, bottom: 10, left: 10, right: 10 },
            disable_smart_shrinking: true,
            zoom: 1,
            javascript_delay: 2000, # optional, falls JS benötigt wird
            lowquality: false,
            no_pdf_compression: false )
        filename = 'SelfDeclarationDataProvider.pdf'

        # create signature barch
        response = HTTMultiParty.post(
            SIGBOX_HOST + '/v2/signaturebatches',
            headers: {
                "Cache-Control" => "no-cache",
                "x-api-key" => ENV['SIGBOX_USER_KEY'].to_s },
            body: {
                "RedirectUrl" => 'https://' + ENV['RAILS_CONFIG_HOSTS'].to_s + '/sigbox/success',
                "ErrorUrl"    => 'https://' + ENV['RAILS_CONFIG_HOSTS'].to_s + '/sigbox/failuer' } )
        location = response.headers['location'] || response.headers['Location']
        ticket = location.split('/').last

        # add PDF to sign
        uri = URI.parse(location + "/documents")
        request = Net::HTTP::Post::Multipart.new(
            uri.path,
            "document" => UploadIO.new(StringIO.new(pdf_binary), "application/pdf", filename),
            "location" => "Signed at the end of the document",
            "reason"   => "Signed to confirm the self-declaration",
            "template" => ENV['SIGBOX_TEMPLATE'] || 23 )
        request['Cache-Control'] = "no-cache"
        request['x-api-key'] = ENV["SIGBOX_USER_KEY"].to_s
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        response = http.request(request)

        # trigger signature process
        response = HTTParty.post(
            location + '/mobileSignature',
            headers: {
                "Cache-Control" => "no-cache",
                "x-api-key" => ENV['SIGBOX_USER_KEY'].to_s } )
        sign_url = response.headers['location'] || response.headers['Location']

        if meta.nil?
            meta = {}
        end
        meta['sigbox_location'] = location

        contract_payload = {
            "contract_type": "Self Declaration",
            "description": "for Data Consumer",
            "did": current_user[:did],
            "bpk": current_user[:bpk],
            "payload": payload
        }

        @store = Store.new(
            item: contract_payload,
            meta: meta,
            schema: meta['schema'].to_s,
            key: ticket,
            user: current_user[:bpk] )

        if !@store.save
          Rails.logger.error("❌ Fehler beim Speichern des Store: #{@store.errors.full_messages}")
          render json: { error: "Could not save Store" }, status: :unprocessable_entity
          return
        end
        contract_id = @store.id.dup

        # create credential-offer for EUDI flow
        preauth_code = SecureRandom.urlsafe_base64(17)[0,22]
        @complete_code = SecureRandom.alphanumeric(10)

        item = {}
        @store = Store.new
        item["preauth-code"] = preauth_code
        item["complete-code"] = @complete_code
        item["contract-id"] = contract_id.to_s
        @store.item = item
        @store.key = preauth_code
        @store.save

        issuer_host = ISSUER_HOST
            payload = {
                "grants": {
                    "urn:ietf:params:oauth:grant-type:pre-authorized_code": {
                        "pre-authorized_code": preauth_code,
                        "user_pin_required": false } },
                "credentials": [CREDENTIAL_SDDP_TYPE],
                "credential_issuer": issuer_host + SDDP_SIGNING_PATH }
        credential_offer = "openid-credential-offer://?credential_offer=" + 
                                URI.encode_www_form_component(payload.to_json)
        qr_light = 'data:image/png;base64,' + Base64.strict_encode64(
                        Barby::QrCode.new(credential_offer, level: :q)
                        .to_png(xdim: 4, foreground: ChunkyPNG::Color::BLACK, 
                                background: ChunkyPNG::Color::WHITE) )
        qr_dark = 'data:image/png;base64,' + Base64.strict_encode64(
                        Barby::QrCode.new(credential_offer, level: :q)
                        .to_png(xdim: 4, foreground: ChunkyPNG::Color::WHITE, 
                                background: ChunkyPNG::Color::BLACK) )



        render json: { url: sign_url, ticket: ticket, 
                       qr_light: qr_light, qr_dark: qr_dark }
    end

    def sigbox_success
        ticket = params[:Ticket].to_s
        @store = Store.find_by_key(ticket)
        if @store.nil?
            puts "Error: can't find record for ticket " + ticket.to_s
            render plain: '',
                   status: 200
        end            

        sigbox_url = SIGBOX_HOST + 
            '/v2/signaturebatches/' +
            ticket.to_s + '/documents/0'
        response = HTTParty.delete(sigbox_url,
            headers: {
                "Cache-Control" => 'no-cache',
                "x-api-key" => ENV['SIGBOX_USER_KEY'].to_s } )
        if response.code != 200
            puts "Error (invalid sigbox response): " + response.code.to_s
            render plain: '',
                   status: 200
        end
        pdf_binary = response.body
        if !(pdf_binary && pdf_binary.bytesize > 1000 && pdf_binary.start_with?("%PDF"))
            puts "❌ PDF scheint beschädigt oder leer"
            render plain: '',
                   status: 200
        end
        @store.repo = 'contracts'
        @store.save
        @store.pdf.attach(
            io: StringIO.new(pdf_binary),
            filename: "SelfDeclarationDataProvider_signed.pdf",
            content_type: "application/pdf" )

        render plain: '',
               status: 200
    end

    def sigbox_failure
        puts params.to_json
        render plain: '',
               status: 200
    end

    private

    def set_view
        @current_page = 'profile'
        @page_title = t('menu.settings')
    end
end
class WelcomeController < ApplicationController
    skip_forgery_protection only: :ida_payload
    
    include ApplicationHelper
    include SessionsHelper
    include EventsHelper

    require 'mail'
    require 'net/smtp'
    require 'net/protocol'

    require 'uri'
    require 'barby'
    require 'barby/barcode'
    require 'barby/barcode/qr_code'
    require 'barby/outputter/png_outputter'
    require 'chunky_png'
    
    def start
        if logged_in?
            redirect_to info_path
            return
        end
        
        # QR Code for Wallet login
        @session_id = SecureRandom.uuid
        @complete_code = SecureRandom.alphanumeric(10)

        item = {}
        item["session-id"] = @session_id
        item["complete-code"] = @complete_code
        item["action"] = "oid4vp"

        @store = Store.new
        @store.item = item
        @store.key = @session_id
        @store.save

        issuer_host = ENV['ISSUER_HOST'] || ISSUER_HOST
        @auth_request = "openid4vp://?request_uri=" +
            URI.encode_www_form_component(issuer_host + AUTH_REQUEST_URI) + @session_id

    end

    # redirect to ID Austria Authentication
    def ida_redirect
        session_id = params[:session_id]
        prefix = ENV['IDA_PREFIX'] || I18n.t('admin.id_austria.state_prefix')
        ida_url = I18n.t('admin.id_austria.ida_host')
        ida_url += '/auth/idp/profile/oidc/authorize'
        ida_url += '?response_type=code'
        ida_url += '&client_id=https%3A%2F%2F' + I18n.t('admin.id_austria.eid_url')
        ida_url += '&redirect_uri=https%3A%2F%2F' + I18n.t('admin.id_austria.eid_url') + '%2Fconnect'
        ida_url += '&scope=openid+profile+eid'
        ida_url += '&state=' + prefix + ':' + session_id.to_s

        createEvent(
            bpk: nil,
            event_str: 'start_ida',
            event_object: {session_id: session_id, ip: request.remote_ip, ida_url: ida_url} )

        redirect_to ida_url, allow_other_host: true
    end

    # redirect coming back from ID Austria Authentication
    def ida_payload
        token = params[:token]
        payload = JWT.decode token, nil, false
        bpk = payload.first['urn:pvpgvat:oidc.bpk']
        sid = payload.first['state'].split(':').last
        @store = Store.find_by_key(sid)
        if @store.nil?
            render json: {"error": "sid not found"},
                   status: 404
            return
        end

        ida_auth_time = payload.first['auth_time']
        given_name = payload.first['given_name']
        last_name = payload.first['family_name']
        postcode = payload.first['org.iso.18013.5.1:resident_postal_code']
        qaa_eidas_level = payload.first['urn:pvpgvat:oidc.eid_citizen_qaa_eidas_level']
        signature = payload.first['urn:pvpgvat:oidc.eid_signer_certificate']

        update_user = true
        @user = User.find_by_bpk(bpk)
        if @user.nil?
            @user = User.new
            update_user = false
        end
        @user.bpk = bpk
        @user.given_name = given_name
        @user.last_name = last_name
        @user.ida_auth_time = ida_auth_time
        @user.postcode = postcode
        @user.qaa_eidas_level = qaa_eidas_level
        @user.signature = signature
        if !@user.save
            createEvent(bpk: bpk, 
                        event_str: 'user_save_error', 
                        event_object: @user.errors.full_messages )
            render json: {"error": "cannot store user data"},
                   status: 500
            return
        end
        if update_user
            createEvent(bpk: bpk, 
                        event_str: 'update_user', 
                        event_object: @user.as_json )
        else
            createEvent(bpk: bpk, 
                        event_str: 'new_user', 
                        event_object: @user.as_json )
        end
        render json: {"bpk": bpk},
               status: 200

    end

    def idaustria
        token = params[:token]
        payload = JWT.decode token, nil, false
        bpk = payload.first['urn:pvpgvat:oidc.bpk']
        sid = payload.first['state'].split(':').last
        @store = Store.find_by_key(sid)
        if @store.nil?
            event_object = {
                token: token,
                payload: payload,
                state: sid
            }
            createEvent(bpk: bpk, 
                        event_str: 'unknown_user', 
                        event_object: event_object)
            flash[:alert] = I18n.t('admin.messages.invalid_login')
            redirect_to start_path
            return
        end
        # delete record so that sid token cannot be reused
        @store.delete

        log_in(bpk)
        createEvent(bpk: bpk, 
                    event_str: 'idaustria_login', 
                    event_object: payload )

        redirect_back_or info_path
    end

    def continue
        complete = params[:complete]
        @store = Store.find_by_key(complete)
        if @store.nil?
            redirect_to start_path
            return
        end

        item = @store.item
        bpk = item['credentialSubject']['bpk']
        log_in(bpk)
        createEvent(bpk: bpk, 
                    event_str: 'wallet_login', 
                    event_object: @store.as_json )
        redirect_back_or info_path
    end

    def user_request

    end

    def submit_user_request
        key = SecureRandom.urlsafe_base64(18)
        item = {}
        item['name'] = params[:name]
        item['email'] = params[:email]
        item['description'] = params[:beschreibung]
        item['reference'] = params[:referenz_kontakt]
        @store = Store.new
        @store.item = item
        @store.key = key
        @store.save

        approval_link = 'https://' + ENV['RAILS_CONFIG_HOSTS'].to_s + '/onboard?token=' + key.to_s

        # send email to configured contact
        subject   = I18n.t('mailers.user_mailer.external_user.subject')
        text_body = I18n.t('mailers.user_mailer.external_user.body_text', 
                         name: params[:name],
                         email: params[:email],
                         description: params[:beschreibung],
                         reference: params[:referenz_kontakt],
                         link: approval_link)
        html_body = I18n.t('mailers.user_mailer.external_user.body_html', 
                         name: params[:name],
                         email: params[:email],
                         description: params[:beschreibung],
                         reference: params[:referenz_kontakt],
                         link: approval_link)

        mail_to = ENV['USER_APPROVAL_EMAIL'] || 'christoph.fabianek@gmail.com'
        mail = Mail.new
        mail.from         = 'no-reply@ownyourdata.eu'
        mail.to           = mail_to
        mail.subject      = 'Approve new user'
        mail.content_type = 'multipart/alternative'
        mail.text_part    = Mail::Part.new { content_type 'text/plain; charset=UTF-8'; body text_body }
        mail.html_part    = Mail::Part.new { content_type 'text/html; charset=UTF-8'; body html_body }

        event_object = {
            email: params[:email].to_s,
            to: mail_to,
            text_body: text_body
        }
        createEvent(
            bpk: nil, 
            event_str: 'external_user_request', 
            event_object: event_object )

        method   = ActionMailer::Base.delivery_method
        settings = ActionMailer::Base.public_send("#{method}_settings")
        mail.delivery_method(method, settings)
        mail.deliver!

        redirect_to start_path, 
                notice: t('welcome.email_sent')
    end

    def onboard
        @record = Store.find_by_key(params[:token].to_s)
        if @record.nil?
            redirect_to start_path
            return
        end
        record_item = @record.item
        lastname = record_item['name']
        bpk = 'extern:' + @record.key
        email = record_item['email']

        # QR code for wallet connection
        preauth_code = SecureRandom.urlsafe_base64(17)[0,22]
        @nonce = SecureRandom.alphanumeric(10)
        @complete_code = SecureRandom.alphanumeric(10)
        @session_id = preauth_code

        item = {}
        item["preauth-code"] = preauth_code
        item["nonce"] = @nonce
        item["complete-code"] = @complete_code
        item["ida_user"] = bpk
        item["ida_given_name"] = ''
        item["ida_family_name"] = lastname
        item["ida_auth_time"] = Time.now.utc

        @store = Store.new
        @store.item = item
        @store.key = preauth_code
        @store.save

        if record_item['user_id'].nil?
            @user = User.new
        else
            @user = User.find(record_item['user_id'])
            if @user.nil?
                @user = User.new
            end
        end
        @user.bpk = bpk
        @user.given_name = ''
        @user.last_name = lastname
        @user.ida_auth_time = Time.now.utc
        @user.postcode = nil
        @user.qaa_eidas_level = 'none'
        @user.signature = nil
        if !@user.save
            createEvent(bpk: bpk, 
                        event_str: 'user_save_error', 
                        event_object: @user.errors.full_messages )
            redirect_to start_path, 
                error: t('admin.messages.error_login')
            return
        end

        record_item['user_id'] = @user.id
        @record.item = record_item
        @record.save

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

    def verify_email
        token = params[:token]
        @user = User.find_by_email_verification_token(token)
        if @user.nil?
            redirect_to start_path, 
                alert: t('admin.messages.unknown_email_token')
            return
        end
        if @user.email_verification_expires_at < DateTime.now 
            redirect_to start_path, 
                alert: t('admin.messages.expired_email_token')
            return
        end
        @user.email_verified = @user.email
        @user.email_verified_at = DateTime.current
        @user.email_verification_token = nil
        if @user.save
            event_object = {
                token: token,
                email: @user.email
            }
            createEvent(
                bpk: @user.bpk, 
                event_str: 'email_verified', 
                event_object: event_object )
            
            redirect_to start_path, 
                notice: t('admin.messages.email_verified')
        else
            redirect_to start_path, 
                error: t('admin.messages.email_verification_failed')
        end
    end

    def logout
        log_out
        redirect_to start_url
    end
end
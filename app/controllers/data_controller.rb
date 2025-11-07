class DataController < ApplicationController
    include ApplicationHelper
    include ValidationHelper
    include SessionsHelper
    include UseCaseHelper
    include Pagy::Backend
    include Sortable

    before_action :logged_in_user
    before_action :set_view
    before_action :set_sorting_support

    def data
        @allowed = {
          "uc" => {
            expr: "COALESCE(#{@json_text.call('item', 'use_case')}, '')",
            default_dir: "asc" },
          "description" => {
            expr: "COALESCE(#{@json_text.call('item', 'description')}, '')",
            default_dir: "asc" }
        }

        order_clause = sort_order(
          allowed:      @allowed,
          default_key:  "uc",
          default_dir:  "asc",
          param_prefix: "data" )
        scope = Store.where(repo: "data")
                     .order(order_clause)
        @pagy, @records = pagy(scope, limit: 15)

        if !flash[:autostart_modal].nil?
            preauth_code = SecureRandom.urlsafe_base64(17)[0,22]
            @complete_code = SecureRandom.alphanumeric(10)

            item = {}
            @store = Store.new
            item["preauth-code"] = preauth_code
            item["complete-code"] = @complete_code
            item["agreement-id"] = flash[:autostart_modal]['d3a_id'].to_s
            @store.item = item
            @store.key = preauth_code
            @store.save

            # create input for QR code
            issuer_host = ISSUER_HOST
            payload = {
                "grants": {
                    "urn:ietf:params:oauth:grant-type:pre-authorized_code": {
                        "pre-authorized_code": preauth_code,
                        "user_pin_required": false } },
                "credentials": [CREDENTIAL_D3A_TYPE],
                "credential_issuer": issuer_host + D3A_SIGNING_PATH }
            @credential_offer = "openid-credential-offer://?credential_offer=" + 
                                    URI.encode_www_form_component(payload.to_json)
        end
    end

    def soya
        @data = Store.find(params[:id])
        if @data.nil?
            render json: {"error": "not found"},
                   status: 404
            return
        end
        soya_webcli_api = SOYA_WEBCLI_HOST + SOYA_WEBCLI_API_PREFIX
        cuc = current_usecase(store_id: @data.id)

        case params[:da].to_s
        when 'share'
            if cuc[:d2a_transform].to_s != ''
                transformation_url = soya_webcli_api + 'transform/' + cuc[:D2A_schema].to_s
                transformation_data = @data.item
                response_nil = false
                begin
                    transformation_response = HTTParty.post(transformation_url, 
                        headers: { 'Content-Type'  => 'application/json' },
                        body: transformation_data.to_json )
                rescue => ex
                    response_nil = true
                end
                if response_nil
                    item_data = @data.item.to_json
                else
                    item_data = transformation_response.parsed_response.to_json
                end
            else
                item_data = @data.item.to_json
            end
            retVal = {
                id: @data.id,
                schema: @data.schema,
                show_delete: (@data.user == current_user[:bpk]),
                url: SOYA_FORM_HOST + 
                        '/?viewMode=form-only' +
                        '&schemaDri=' + cuc[:D2A_schema].to_s +
                        '&tag=d2a_read' + 
                        '&language=' + I18n.locale.to_s +
                        '&data=' + CGI.escape(item_data)
            }
        when 'disclose'
            item_data = {}
            retVal = {
                id: @data.id,
                schema: cuc[:D3A_schema].to_s,
                url: SOYA_FORM_HOST + 
                        '/?viewMode=form-only' +
                        '&schemaDri=' + cuc[:D3A_schema].to_s +
                        '&tag=' + cuc[:d3a_edit].to_s +
                        '&language=' + I18n.locale.to_s +
                        '&data=' + CGI.escape(item_data.to_json)
            }
        end
        render json: retVal,
               status: 200

    end

    def delete
        id = params[:id]
        @record = Store.find(id) rescue nil
        if @record.nil?
            flash[:alert] = t('admin.messages.operation_canceled')
        else
            if @record.user == current_user[:bpk]
                createEvent(bpk: @record.user, 
                            event_str: 'data_delete', 
                            event_object: @record.as_json)
                if @record.destroy
                    flash[:notice] = t('data.msg_record_deleted')
                else
                    flash[:alert] = t('admin.messages.operation_canceled')
                end
            else
                flash[:alert] = t('admin.messages.not_authorized')
            end
        end
        redirect_to data_path
    end

    def d3a
        payload = JSON.parse(params[:payload]).transform_keys(&:to_sym) rescue {}
        meta = JSON.parse(params[:meta]).transform_keys(&:to_sym) rescue {}
        schema = meta[:schema] rescue ''
        cuc = current_usecase(store_id: meta[:id])
        case params[:commit_action]
        when 'validate'
            input_valid, input_msg = validate(payload, schema)

            @store = Store.find(meta[:id])
            source_d2a = @store.item['consent'] || {} rescue {}
            d2a_duration = source_d2a['hasExpiryTime'] rescue nil
            d2a_expiry_time = d2a_expiry_time = expiry_from_duration(d2a_duration)
            source_d2a['hasExpiryTime'] = d2a_expiry_time

            target_d3a = payload[:consent] || {} rescue {}
            d3a_duration = target_d3a['hasExpiryTime'] rescue nil
            d3a_expiry_time = expiry_from_duration(d3a_duration)
            target_d3a['hasExpiryTime'] = d3a_expiry_time
            reasoner_input = {
                ontology: SOYA_REPO_HOST + '/' + cuc[:da_reasoner],
                    d2aConsent: source_d2a,
                    d3aConsent: target_d3a }
            response = HTTParty.put(REASONER_URL,
                headers: { 'Content-Type' => 'application/json' },
                body: reasoner_input.to_json)
            # evaluate result
            if response.parsed_response.is_a?(String)
                pr = JSON.parse(response.parsed_response)
            end
            reasoner_valid = pr['valid']
            valid = input_valid && reasoner_valid
            valid_msg = pr['messages']
            if valid
                msg = nil
            else
                msg = [input_msg, valid_msg].flatten.compact.reject(&:blank?).join('; ')
            end
            display_message = msg || (valid ? t('forms.validation.ok') : t('forms.validation.failed'))
            html = render_to_string(
              partial: 'layouts/validation_flash',
              formats: [:html],
              locals: { type: (valid ? :success : :danger), 
                        message: display_message.to_s } )
            respond_to do |format|
              format.json { render json: { valid: valid, html: html } }
              format.html { render html: html }
            end
            return

        when 'save' # not yet implemented (might go into MyAssets?)

        when 'sign'
            retVal, errMsg = save_d3a(payload, meta)
            if errMsg.to_s == ''
                flash[:autostart_modal] = { kind: "sign", d3a_id: retVal[:d3a_id] }
            end
        else
            errMsg = I18n.t('admin.message.invalid_input')
        end
        if errMsg.to_s != ''
            flash[:error] = errMsg
        end
        redirect_to data_path
    end

    private

    def set_view
        @current_page = 'data'
        @page_title = t('menu.data')
    end

    def save_d3a(item_data, meta_data)
        if item_data.nil?
            return [nil, 'missing data']
        end

        if meta_data.nil?
            return [nil, 'missing meta data']
        end

        schema = meta_data.delete(:schema) rescue nil
        if schema.nil?
            return [nil, 'missing schema']
        end
        data_id = meta_data.delete(:id) rescue nil
        if data_id.nil?
            return [nil, 'missing d2a reference']
        end

        user = current_user[:bpk]
        if user.nil?
            return [nil, 'missing user']
        end

        if meta_data[:repo].nil?
            meta_data[:repo] = 'd3a'
        end

        item_data = JSON.parse(item_data.to_json)
        receiverType = item_data["subject"]["receiverType"] || "undefined" rescue "undefined"
        receiverRegisteredNumber = item_data["subject"]["receiverRegisteredNumber"] || "empty" rescue "empty"

        description = "Data Disclosure Agreement"
        description += ' (' + receiverType
        description += ' #' + receiverRegisteredNumber + ')'
        cuc = current_usecase(schema: schema)
        item_data[:description] = description
        item_data[:use_case] = cuc[:title]
        item_data[:data_id] = data_id

        dri = Oydid.hash(Oydid.canonical({"data": item_data, "meta": meta_data}.to_json))
        if !meta_data[:id].nil?
            @store = Store.find(meta_data[:id])
            meta_data.delete(:id)
            if !@store.nil?
                update = true
            end
        end

        @store = Store.new
        @store.item = item_data
        @store.meta = meta_data
        @store.schema = schema
        @store.repo = meta_data[:repo]
        @store.user = user
        @store.dri = dri
        if !@store.save
            return [nil, @store.errors.full_messages.join(' ')]
        end

        retVal = {"dri": dri.to_s, "d2a_id": data_id, "d3a_id": @store.id, "object-id": @store.id, "name": description}
        createEvent(bpk: user, 
                    event_str: 'd3a_save', 
                    event_object: item_data.merge(retVal) )
        return [retVal, nil]
    end
end

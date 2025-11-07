class AssetController < ApplicationController
    include ApplicationHelper
    include ValidationHelper
    include SessionsHelper
    include Pagy::Backend
    include UseCaseHelper
    include Sortable

    before_action :logged_in_user
    before_action :set_view
    before_action :set_sorting_support

    def asset
        json_text = ->(path) { "data #>> '{#{Array(path).join(',')}}'" }
        @allowed = {
          "time"        => { expr: "created_at",                           default_dir: "desc" },
          "uc"          => { expr: @json_text.call("item", "use_case"),    default_dir: "asc"  },
          "description" => { expr: @json_text.call("item", "description"), default_dir: "asc"  }
        }

        order_clause = sort_order(
            allowed:      @allowed,
            default_key:  "time",
            default_col:  "created_at",
            default_dir:  "desc",
            param_prefix: "assets" )
        scope = Store.where(user: current_user[:bpk], repo: "assets")
                     .order(order_clause)        
        @pagy, @records = pagy(scope, limit: 15)

        if !flash[:autostart_modal].nil?
            preauth_code = SecureRandom.urlsafe_base64(17)[0,22]
            @complete_code = SecureRandom.alphanumeric(10)

            item = {}
            @store = Store.new
            item["preauth-code"] = preauth_code
            item["complete-code"] = @complete_code
            item["agreement-id"] = flash[:autostart_modal]['asset_id'].to_s
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
                "credentials": [CREDENTIAL_D2A_TYPE],
                "credential_issuer": issuer_host + D2A_SIGNING_PATH }
            @credential_offer = "openid-credential-offer://?credential_offer=" + 
                                    URI.encode_www_form_component(payload.to_json)
        end
    end

    def uc_soya
        uc = params[:kind].to_s
        retVal = {}
        cuc = current_usecase(short: uc)
        retVal[:url] = SOYA_FORM_HOST + 
                '/?viewMode=form-only' +
                '&schemaDri=' + cuc[:D2A_schema] +
                '&tag=' + cuc[:d2a_edit] + 
                '&language=' + I18n.locale.to_s
        retVal[:schema] = cuc[:D2A_schema]
        title = cuc[:title]
        curr_bpk = current_user[:bpk]
        createEvent(bpk: curr_bpk, 
                    event_str: 'd2a_init', 
                    event_object: retVal.merge(title: title, uc: uc) )
        if retVal != {}
            render json: retVal
        else
            render json: { error: "unknown use case" }, status: :unprocessable_entity
        end
    end

    def delete
        id = params[:id] rescue nil
        @store = Store.find(id) rescue nil
        if @store.nil?
            flash[:warning] = I18n.('admin.message.invalid_input')
        else
            curr_bpk = current_user[:bpk]
            if @store.user == curr_bpk
                if @store.delete
                    createEvent(bpk: curr_bpk, 
                                event_str: 'asset_delete', 
                                event_object: @store.as_json )                    
                    flash[:info] = I18n.t('asset.msg_record_deleted')
                else
                    flash[:warning] = I18n.('admin.message.operation_not_completed')
                end
            else
                flash[:warning] = I18n.('admin.message.invalid_input')
            end
        end
        redirect_to assets_path
    end

    def d2a
        payload = JSON.parse(params[:payload]).transform_keys(&:to_sym)
        meta = JSON.parse(params[:meta]).transform_keys(&:to_sym)
        schema = meta[:schema] rescue ''
        case params[:commit_action]
        when 'validate'
            valid, msg = validate(payload, schema)
            html = render_to_string(
              partial: 'layouts/validation_flash',
              formats: [:html],
              locals: { type: (valid ? :success : :danger), 
                        message: (msg || (valid ? t('forms.validation.ok') : t('forms.validation.failed'))) } )
            respond_to do |format|
              format.json { render json: { valid: valid, html: html } }
              format.html { render html: html }
            end
            return

        when 'save'
            retVal, errMsg = save_d2a(payload, meta)
            if errMsg.to_s == ''
                flash[:info] = I18n.t('forms.msg_saved')
            end
        when 'sign'
            retVal, errMsg = save_d2a(payload, meta)
            if errMsg.to_s == ''
                flash[:autostart_modal] = { kind: "sign", asset_id: retVal[:id] }
            end
        else
            errMsg = I18n.t('admin.message.invalid_input')
        end
        if errMsg.to_s != ''
            flash[:error] = errMsg
        end

        redirect_to assets_path
    end

    def soya
        @asset = Store.find(params[:id])
        if @asset.nil? || @asset.user != current_user[:bpk]
            render json: {"error": "not found"},
                   status: 404
            return
        end
        retVal = {
            id: @asset.id,
            schema: @asset.schema,
            url: SOYA_FORM_HOST + 
                    '/?viewMode=form-only&schemaDri=' + @asset.schema +
                    '&tag=d2a_edit' + 
                    '&language=' + I18n.locale.to_s +
                    '&data=' + CGI.escape(@asset.item.to_json)
        }
        render json: retVal,
               status: 200

    end

    private

    def set_view
        @current_page = 'asset'
        @page_title = t('menu.asset')
    end

    def save_d2a(item_data, meta_data)
        update = false
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

        user = current_user[:bpk]
        if user.nil?
            return [nil, 'missing user']
        end

        if meta_data[:repo].nil?
            meta_data[:repo] = "assets"
        end

        item_data = JSON.parse(item_data.to_json)
        description = "Draft - Data Sharing Agreement: "
        case schema
        when "D2Aeeg"
            providerType = item_data["subject"]["eegType"] || "undefined" rescue "undefined"
            providerNr = item_data["subject"]["eegRegisteredNumber"] || "empty" rescue "empty"

            description = "Draft - Data Sharing Agreement"
            description += ' (' + providerType
            description += ' #' + providerNr + ')'
        else
            providerTitle = item_data["subject"]["providerTitle"] || "missing" rescue "missing"
            providerType = item_data["subject"]["providerType"] || "undefined" rescue "undefined"
            providerNr = item_data["subject"]["providerRegisteredNumber"] || "empty" rescue "empty"

            description = "Draft - Data Sharing Agreement"
            description += ' - ' + providerTitle
            description += ' (' + providerType
            description += ' #' + providerNr + ')'
        end

        cuc = current_usecase(schema: schema)
        item_data[:description] = description
        item_data[:use_case] = cuc[:title]

        dri = Oydid.hash(Oydid.canonical({"data": item_data, "meta": meta_data}.to_json))
        if !meta_data[:id].nil?
            @store = Store.find(meta_data[:id])
            meta_data.delete(:id)
            if !@store.nil?
                update = true
            end
        end
        if !update
            @store = Store.new
        end
        @store.item = item_data
        @store.meta = meta_data
        @store.schema = schema
        @store.repo = meta_data[:repo]
        @store.user = user
        @store.dri = dri
        if !@store.save
            return [nil, @store.errors.full_messages.join(' ')]
        end

        retVal = {"dri": dri.to_s, "id": @store.id, "object-id": @store.id, "name": description}

        if update
            createEvent(bpk: user, 
                        event_str: 'd2a_update', 
                        event_object: item_data )
        else
            createEvent(bpk: user, 
                        event_str: 'd2a_save', 
                        event_object: item_data )
        end

        return [retVal, nil]
    end
end
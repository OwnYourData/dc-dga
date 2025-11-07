class ContractController < ApplicationController
    include ApplicationHelper
    include ValidationHelper
    include SessionsHelper
    include Pagy::Backend
    include UseCaseHelper
    include Sortable

    before_action :logged_in_user
    skip_before_action :logged_in_user, only: :soya_url
    before_action :authorize_with_oauth, only: :soya_url
    before_action :set_view
    before_action :set_sorting_support

    def contracts
        json_text = ->(path) { "data #>> '{#{Array(path).join(',')}}'" }
        @allowed = {
          "time"        => { expr: "created_at",                             default_dir: "desc" },
          "contract"    => { expr: @json_text.call("item", "contract_type"), default_dir: "asc"  },
          "description" => { expr: @json_text.call("item", "description"),   default_dir: "asc"  }
        }

        order_clause = sort_order(
            allowed:      @allowed,
            default_key:  "time",
            default_col:  "created_at",
            default_dir:  "desc",
            param_prefix: "contract" )
        scope = Store.where(user: current_user[:bpk], repo: "contracts")
                     .order(order_clause)        
        @pagy, @records = pagy(scope, limit: 15)

    end

    def soya
        @data = Store.find(params[:id])
        if @data.nil?
            render json: {"error": "not found"},
                   status: 404
            return
        end
        cuc = current_usecase(store_id: @data.id)
        if !cuc.nil? && cuc[:soya_url]
            schema = cuc[:contract_schema]
            short_lived_token = 'asdf'
            soya_url_string = ISSUER_HOST + 
                '/contract/soya_url' +
                '?id=' + @data.id.to_s
            @oauth_app = Doorkeeper::Application.find_by_name('soya')
            short_lived_token = Doorkeeper::AccessToken.create!(
                application: @oauth_app,
                scopes: 'read',
                expires_in: 2.minutes.to_i,
                use_refresh_token: false )
            retVal = {
                id: @data.id,
                schema: schema,
                show_delete: (@data.user == current_user[:bpk]),
                url: SOYA_FORM_HOST + 
                        '/?viewMode=form-only' +
                        '&schemaDri=' + schema +
                        '&tag=read_only' + 
                        '&language=' + I18n.locale.to_s +
                        '&url=' + CGI.escape(soya_url_string) + 
                        '&token=' + short_lived_token.token }
        else
            if !cuc.nil? && cuc[:consent_schema].to_s == @data.schema.to_s
                if cuc[:contract_transfrom].to_s != ''
                    schema = cuc[:contract_schema]
                    soya_webcli_api = SOYA_WEBCLI_HOST + SOYA_WEBCLI_API_PREFIX
                    transformation_url = soya_webcli_api + 'transform/' + schema.to_s
                    transformation_data = @data.item["payload"]
                    response_nil = false
                    begin
                        transformation_response = HTTParty.post(transformation_url, 
                            headers: { 'Content-Type'  => 'application/json' },
                            body: transformation_data.to_json )
                    rescue => ex
                        response_nil = true
                    end
                    if response_nil
                        data_item = @data.item
                    else
                        data_item = transformation_response.parsed_response
                    end
                else
                    schema = @data.schema
                    data_item = @data.item["payload"]
                end
            else
                schema = @data.schema
                data_item = @data.item["payload"]
            end
            retVal = {
                id: @data.id,
                schema: schema,
                show_delete: (@data.user == current_user[:bpk]),
                url: SOYA_FORM_HOST + 
                        '/?viewMode=form-only' +
                        '&schemaDri=' + schema +
                        '&tag=read_only' + 
                        '&language=' + I18n.locale.to_s +
                        '&data=' + CGI.escape(data_item.to_json)
            }
        end
        render json: retVal,
               status: 200

    end

    def soya_url
        @data = Store.find(params[:id])
        if @data.nil?
            render json: {},
                   status: 200
            return
        end
        cuc = current_usecase(store_id: @data.id)
        if !cuc.nil? && cuc[:consent_schema].to_s == @data.schema.to_s
            if cuc[:contract_transfrom].to_s != ''
                schema = cuc[:contract_schema]
                soya_webcli_api = SOYA_WEBCLI_HOST + SOYA_WEBCLI_API_PREFIX
                transformation_url = soya_webcli_api + 'transform/' + schema.to_s
                transformation_data = @data.item["payload"]
                response_nil = false
                begin
                    transformation_response = HTTParty.post(transformation_url, 
                        headers: { 'Content-Type'  => 'application/json' },
                        body: transformation_data.to_json )
                rescue => ex
                    response_nil = true
                end
                if response_nil
                    data_item = @data.item
                else
                    data_item = transformation_response.parsed_response
                end
            else
                schema = @data.schema
                data_item = @data.item["payload"]
            end
        else
            schema = @data.schema
            data_item = @data.item["payload"]
        end
        render json: data_item,
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
                            event_str: 'contract_delete', 
                            event_object: @record.as_json)
                if @record.destroy
                    flash[:notice] = t('contract.msg_record_deleted')
                else
                    flash[:alert] = t('admin.messages.operation_canceled')
                end
            else
                flash[:alert] = t('admin.messages.not_authorized')
            end
        end
        redirect_to contracts_path
    end

    def pdf_download
        @rec = Store.find(params[:id])
        return head :not_found unless @rec.respond_to?(:pdf) && @rec.pdf.attached?

        fname =
        if @rec.respond_to?(:name) && @rec.name.present?
          "#{@rec.name.parameterize}.pdf"
        else
          "contract-#{@rec.id}.pdf"
        end

        send_data @rec.pdf.download,
                filename: fname,
                type: @rec.pdf.content_type || "application/pdf",
                disposition: "attachment"
    end

    private

    def set_view
        @current_page = 'contract'
        @page_title = t('menu.contract')
    end

    def authorize_with_oauth
        doorkeeper_authorize! :read, :write, :admin
    end
end

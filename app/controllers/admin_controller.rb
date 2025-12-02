class AdminController < ApplicationController
    include ApplicationHelper
    include SessionsHelper
    include UseCaseHelper

    def check
        @store = Store.find_by_key(params[:complete]) rescue nil
        render json: { retVal: @store.present? }, status: :ok
    end

    def check_signed
        @store = Store.find_by_key(params[:id]) rescue nil
        if @store.nil?
            render json: {signed: false}, status: :ok
        else
            if @store.repo == 'contracts'
                render json: {signed: true}, status: :ok
            else
                render json: {signed: false}, status: :ok
            end
        end
        # render json: { retVal: @store.present? }, status: :ok

    end

    def d2a_signed
        complete = params[:complete]
        @store = Store.find_by_key(complete)
        item = @store.item
        if item.is_a?(String)
            item = JSON.parse(item) rescue {}
        end
        @rec = Store.find(item["agreement-id"])
        if @rec.nil?
            flash[:warning] = I18n.('admin.message.operation_not_completed')
        else
            schema = @rec.schema
            # process according to Data Agreement type
            case schema
            when "D2Aeeg"
                success, error_message = process_D2Aeeg_signature(@store.id)
            when "D2AapiSharing"
                success, error_message = process_D2AapiSharing_signature(@store.id)
            end
            if success
                flash[:info] = I18n.t('asset.msg_signed')
                @rec.delete
                createEvent(bpk: current_user[:bpk], 
                            event_str: 'd2a_sign', 
                            event_object: @rec.as_json)
            else
                flash[:warning] = error_message || 'Error'
            end
        end
        redirect_to assets_path
    end

    def d3a_signed
        complete = params[:complete]
        @store = Store.find_by_key(complete)
        item = @store.item
        if item.is_a?(String)
            item = JSON.parse(item) rescue {}
        end
        @rec = Store.find(item["agreement-id"])
        if @rec.nil?
            flash[:warning] = I18n.('admin.message.operation_not_completed')
        else
            schema = @rec.schema
            # process according to Data Agreement type
            case schema
            when "D3Aeeg"
                success, error_message = process_D3Aeeg_signature(@store.id)
            when 'D3AapiSharing'
                success, error_message = process_D3AapiSharing_signature(@store.id)
            end
            if success
                flash[:info] = I18n.t('data.msg_signed')
                @rec.delete
                createEvent(bpk: current_user[:bpk], 
                            event_str: 'd3a_sign', 
                            event_object: @rec.as_json)
            else
                flash[:warning] = error_message
            end
        end
        redirect_to data_path
    end

end
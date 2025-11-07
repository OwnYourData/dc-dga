class LogController < ApplicationController
    include ApplicationHelper
    include SessionsHelper
    include Pagy::Backend
    include Sortable

    before_action :logged_in_user
    before_action :set_view

    def logs
        order_clause = sort_order(
            allowed:      { "time" => "timestamp", 
                            "event" => "event" },
            default_key:  "time",
            default_col:  "timestamp",
            default_dir:  "desc",
            param_prefix: "logs" )
        scope = Event.where(user: current_user[:bpk])
                     .order(order_clause)
        @pagy, @events = pagy(scope, limit: 15)
    end

    def object
        event = Event.find(params[:id])
        if event.event_object.is_a?(String)
            render json: JSON.parse(event.event_object)
        else
            render json: event.event_object
        end
    end

    private

    def set_view
        @current_page = 'log'
        @page_title = t('menu.log')
    end
end
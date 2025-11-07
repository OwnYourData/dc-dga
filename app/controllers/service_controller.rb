class ServiceController < ApplicationController
    include ApplicationHelper
    include ValidationHelper
    include SessionsHelper
    include Pagy::Backend
    include Sortable

    before_action :logged_in_user
    before_action :set_view
    before_action :set_sorting_support

    def services
        @allowed = {
          "provider" => {
            expr: "COALESCE(#{@json_text.call('item', 'service_provider')}, '')",
            default_dir: "asc" },
          "title" => {
            expr: "COALESCE(#{@json_text.call('item', 'title')}, '')",
            default_dir: "asc" }
        }

        order_clause = sort_order(
          allowed:      @allowed,
          default_key:  "provider",
          default_dir:  "asc",
          param_prefix: "service" )
        scope = Store.where(repo: "service")
                     .order(order_clause)
        @pagy, @records = pagy(scope, limit: 15)

    end

    private

    def set_view
        @current_page = 'service'
        @page_title = t('menu.service')
    end
end

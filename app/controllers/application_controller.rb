class ApplicationController < ActionController::Base
    include NavigationHelper
    
    before_action :set_locale

    def version
        render json: {"app": "DGA", "version": VERSION.to_s, "oydid-gem": Gem.loaded_specs["oydid"].version.to_s}.to_json,
               status: 200
    end

    def missing
        render json: {"error": "invalid path"},
               status: 404
    end

    private

    def extract_locale_from_accept_language_header
        hal = request.env['HTTP_ACCEPT_LANGUAGE']
        if hal
            retval = hal.scan(/^[a-z]{2}/).first
            if "-en-de-".split(retval).count == 2
                retval
            else
                I18n.default_locale
            end
        else
            I18n.default_locale
        end
    end
    
    def set_locale
        I18n.locale = params[:locale] || extract_locale_from_accept_language_header
        Rails.application.routes.default_url_options[:locale]= I18n.locale
    end

end
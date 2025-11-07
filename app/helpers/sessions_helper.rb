module SessionsHelper
    include EventsHelper

    def log_in(token)
        session[:token] = token
    end

    def current_user
        current_user = get_user(session[:token]) rescue nil
    end

    def get_user(token)
        user = User.find_by_bpk(token) rescue nil
        return unless user
        { id: user.id, bpk: user.bpk, did: user.did, 
          name: user.last_name, first_name: user.given_name,
          signature: user.signature,
          full_name: user.given_name + ' ' + user.last_name }
    end

    def logged_in?
        !current_user.nil?
    end

    def log_out
        user_info = get_user(session[:token]) rescue nil
        if !user_info.nil?
            createEvent(
                bpk: user_info[:bpk], 
                event_str: 'logout', 
                event_object: user_info.as_json )
        end

        session.delete(:token)
        current_user = nil
    end

    def redirect_back_or(default)
        redirect_to(session[:forwarding_url] || default)
        session.delete(:forwarding_url)
    end

    def store_location
        session[:forwarding_url] = request.original_url if request.get?
    end

    def valid_email?(string)
        !!(string =~ URI::MailTo::EMAIL_REGEXP)
    end

    private 

    def logged_in_user
        unless logged_in?
            store_location
            flash[:alert] = I18n.t('admin.messages.authenticate')
            redirect_to start_path
        end
    end
end

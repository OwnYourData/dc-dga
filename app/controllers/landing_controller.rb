class LandingController < ApplicationController
    
    include ApplicationHelper
    include SessionsHelper
    include EventsHelper

    def home
        @faq = Knowledgebase.where(lang: I18n.locale).order(:position)
        @contact_request = ContactRequest.new
    end

    def imprint
    end

    def privacy
    end

    def new_contact
        @contact_request = ContactRequest.new
    end

    def create_contact
        @contact_request = ContactRequest.new(contact_request_params)
        if @contact_request.honeypot.present?
            Rails.logger.warn "ContactRequest spam blocked (honeypot): #{request.remote_ip}"
            head :ok
            return
        end

        if @contact_request.save
            # hier ggf. Mail verschicken
            # ContactRequestMailer.notify(@contact_request).deliver_later
            redirect_to root_path, notice: "Vielen Dank für Ihre Nachricht."
        else
            render :new, status: :unprocessable_entity
        end
    end

    private

    def contact_request_params
        params.require(:contact_request).permit(:name, :email, :message, :honeypot)
    end

end
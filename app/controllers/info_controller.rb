class InfoController < ApplicationController
    include ApplicationHelper
    include SessionsHelper

    before_action :logged_in_user
    before_action :set_view

    def info
        @user = User.find(current_user[:id])
        if !@user.nil?
            if @user.email_verified.to_s == ''
                flash[:info] = I18n.t('admin.messages.provide_email')
            else
                if @user.did.to_s == ''
                    flash[:info] = I18n.t('admin.messages.connect_wallet')
                else
                    if @user.did_valid_until && @user.did_valid_until < DateTime.now
                        flash[:info] = I18n.t('admin.messages.reconnect_wallet')
                    end
                end
            end
        end
        @knowledgebases = Knowledgebase.where(frontpage: true, lang: I18n.locale).order(:position)
    end

    def faq
        @knowledgebases = Knowledgebase.where(lang: I18n.locale).order(:position)
    end

    def article
        @knowledgebase = Knowledgebase.find_by!(short: params[:id], lang: I18n.locale.to_s)
    end

    private

    def set_view
        @current_page = 'info'
        @page_title = t('menu.help_title')
    end
end
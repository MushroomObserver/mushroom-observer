# frozen_string_literal: true

# =============== Controls access to admin mode ================
#
# NOTE:
# Unlike controllers inheriting from AdminController, this controller's
# actions do not require current user to be an admin already in admin mode,
#        i.e. a user where     @user.admin && in_admin_mode
#
# This controller is for turning admin mode on and off, and switching users.
# (If an admin switches to another user, that user may not be an admin.)

module Admin
  class SessionController < ApplicationController
    before_action :login_required

    # The route to turn admin mode on or off. Takes params.
    def create
      if params[:turn_on]
        session[:admin] = true if @user&.admin && !in_admin_mode?
      elsif params[:turn_off]
        session[:admin] = nil
        return redirect_to("/") if referer_is_admin_only?
      end

      redirect_back_or_to("/")
    end

    # Form for admins to switch users
    def edit
      if !@user&.admin && session[:real_user_id].blank?
        redirect_back_or_default("/") and return
      end

      @form = FormObject::AdminSession.new
      render(Views::Controllers::Admin::Session::Edit.new(form: @form))
    end

    # Action to switch the apparent logged-in user, session[:user_id]
    # Stores the admin's session[:user_id] as session[:real_user_id]
    def update
      # Prefer user_id from autocompleter hidden field, fall back to text input
      @id = params.dig(:admin_session, :user_id).presence ||
            params.dig(:admin_session, :user).presence ||
            params[:id].to_s

      new_user = find_user_by_id_login_or_email(@id)
      if new_user.blank? && @id.present?
        flash_error(:runtime_admin_switch_users_not_found.t(id: @id))
        redirect_to(action: :edit)
      # Allow non-admin that's already in "switch user mode" to switch to
      # another user. This is a weird case which only comes up if you switch to
      # another admin user.  But if you do so the Switch User mechanism should
      # behave in a reasonable way, and this seems the most appropriate way.
      elsif !@user&.admin && session[:real_user_id].blank?
        redirect_back_or_default("/")
      elsif new_user.present?
        switch_to_user_if_verified(new_user)
        redirect_to(action: :edit)
      end
    end

    private

    # Turning admin mode off while viewing an admin-only page (e.g. a
    # License) would otherwise redirect_back into that page, which
    # immediately bounces to AdminController#access_denied with a
    # startling "Permission denied" flash -- graceless for someone who
    # just intentionally turned admin mode off, not someone genuinely
    # denied access. Detect that case and skip straight to "/" instead.
    def referer_is_admin_only?
      return false unless request.referer

      path = URI.parse(request.referer).path
      route = Rails.application.routes.recognize_path(path)
      controller_class = "#{route[:controller].camelize}Controller".
                         safe_constantize
      return false unless controller_class

      controller_class <= AdminController
    rescue URI::InvalidURIError, ActionController::RoutingError
      false
    end

    def switch_to_user_if_verified(new_user)
      if new_user.verified
        switch_to_user(new_user)
      else
        flash_error(:runtime_admin_switch_users_not_verified.t)
      end
    end

    def find_user_by_id_login_or_email(str)
      if str.blank?
        nil
      elsif str.match?(/^\d+$/)
        User.safe_find(str)
      else
        # Handles "Full Name (login)" format from autocompleter, plain login,
        # or email address
        User.lookup_unique_text_name(str) || User.find_by(email: str)
      end
    end
  end
end

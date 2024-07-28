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
      end

      redirect_back_or_default("/")
    end

    # Form for admins to switch users
    def edit
      redirect_back_or_default("/") if
        !@user&.admin && session[:real_user_id].blank?
    end

    # Action to switch the apparent logged-in user, session[:user_id]
    # Stores the admin's session[:user_id] as session[:real_user_id]
    def update
      @id = params[:id].to_s
      # autocomplete returns "nathan <Nathan Wilson>" - we only want the login
      @id = @id.split(" <")[0].strip if @id.is_a?(String) && @id.exclude?("@")

      new_user = find_user_by_id_login_or_email(@id)
      if new_user.blank? && @id.present?
        flash_error("Couldn't find \"#{@id}\".  Play again?")
        render(action: :edit)
      # Allow non-admin that's already in "switch user mode" to switch to
      # another user. This is a weird case which only comes up if you switch to
      # another admin user.  But if you do so the Switch User mechanism should
      # behave in a reasonable way, and this seems the most appropriate way.
      elsif !@user&.admin && session[:real_user_id].blank?
        redirect_back_or_default("/")
      elsif new_user.present?
        switch_to_user_if_verified(new_user)
        render(action: :edit)
      end
    end

    private

    def switch_to_user_if_verified(new_user)
      if new_user.verified
        switch_to_user(new_user)
      else
        flash_error("This user is not verified yet!")
      end
    end

    def switch_to_user(new_user)
      # This happens if an admin switches to another user from themselves.
      if session[:real_user_id].blank?
        session[:real_user_id] = User.current_id
        session[:admin] = nil
      # This happens if an admin in "switch user mode" logs out or explicitly.
      # switches back to themselves.
      elsif session[:real_user_id] == new_user.id
        session[:real_user_id] = nil
        session[:admin] = true
      end
      # This happens if an admin already in "switch user mode" switches to yet
      # another user.
      User.current = new_user
      session_user_set(new_user)
    end

    def find_user_by_id_login_or_email(str)
      if str.blank?
        nil
      elsif str.match?(/^\d+$/)
        User.safe_find(str)
      else
        User.find_by(login: str) || User.find_by(email: str.sub(/ <.*>$/, ""))
      end
    end
  end
end

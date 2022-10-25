# frozen_string_literal: true

# Defines admin access level used across all the admin controllers.
# It extends the "login_required" filter defined in classes/login_system
module Admin
  module RestrictAccessToAdminMode
    def authorize?(_user)
      in_admin_mode?
    end

    def access_denied
      flash_error(:permission_denied.t)
      if session[:user_id]
        redirect_to("/")
      else
        redirect_to(new_account_login_path)
      end
    end
  end
end

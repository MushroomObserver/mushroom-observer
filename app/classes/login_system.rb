# frozen_string_literal: true

# Methods to restrict method access to logged-in users
module LoginSystem
  protected

  # Allow ip's like our stats requests to get through, so we know if the site
  # is getting slower or faster.
  def allowed?(ip)
    return true if ["127.0.0.1"].include?(ip.to_s)

    false
  end

  # login_required filter. add
  #
  #   before_action :login_required
  #
  def login_required
    return true if allowed?(request.remote_ip) && Rails.env.production?

    return true if session_user

    # store current location so that we can
    # come back after the user logged in
    store_location

    # call overwriteable reaction to unauthorized access
    access_denied
    false
  end

  # overwrite if you want to have special behavior in case the user
  # is not authorized to access the current operation.
  # the default action is to redirect to the login screen
  # example use :
  # a popup window might just close itself for instance
  def access_denied
    redirect_to(new_account_login_path)
  end

  # store current uri in  the session.
  # we can return to this location by calling return_location
  def store_location
    session["return-to"] = request.fullpath
  end

  # move to the last store_location call or to the passed default one
  def redirect_back_or_default(default)
    if session["return-to"].nil?
      redirect_to(default)
    else
      redirect_to(session["return-to"])
      session["return-to"] = nil
    end
  end
end

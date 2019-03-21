# frozen_string_literal: true

require_dependency "user"

# Methods to restrict method access to logged-in users
module LoginSystem
  protected

  # overwrite this if you want to restrict access to only a few actions
  # or if you want to check if the user has the correct rights
  # example:
  #
  #  # only allow nonbobs
  #  def authorize?(user)
  #    user.login != "bob"
  #  end
  def authorize?(_user)
    true
  end

  # overwrite this method if you only want to protect certain actions
  # of the controller
  # example:
  #
  #  # don't protect the login and the about method
  #  def protect?(action)
  #    if ['action', 'about'].include?(action)
  #       return false
  #    else
  #       return true
  #    end
  #  end
  def protect?(_action)
    true
  end

  # login_required filter. add
  #
  #   before_action :login_required
  #
  # if the controller should be under any rights management.
  # for finer access control you can overwrite
  #
  #   def authorize?(user)
  #
  def login_required
    return true unless protect?(action_name)

    user = session_user
    return true if user && authorize?(user)

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
    redirect_to controller: "account", action: "login"
  end

  # store current uri in  the session.
  # we can return to this location by calling return_location
  def store_location
    session["return-to"] = request.fullpath
  end

  # move to the last store_location call or to the passed default one
  def redirect_back_or_default(default)
    if session["return-to"].nil?
      redirect_to default
    else
      redirect_to session["return-to"]
      session["return-to"] = nil
    end
  end
end

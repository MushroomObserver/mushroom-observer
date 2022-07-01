# frozen_string_literal: true

######### Browser JS utility methods
class JavascriptController < ApplicationController
  before_action :login_required, except: [
    :turn_javascript_nil,
    :turn_javascript_off,
    :turn_javascript_on
  ]

  # Force javascript on.
  def turn_javascript_on
    session[:js_override] = :on
    flash_notice(:turn_javascript_on_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to("/")
  end

  # Force javascript off.
  def turn_javascript_off
    session[:js_override] = :off
    flash_notice(:turn_javascript_off_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to("/")
  end

  # Enable auto-detection.
  def turn_javascript_nil
    session[:js_override] = nil
    flash_notice(:turn_javascript_nil_body.t)
    redirect_to(:back)
  rescue ActionController::RedirectBackError
    redirect_to("/")
  end
end

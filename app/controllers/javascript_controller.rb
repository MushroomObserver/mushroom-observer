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

  def hide_thumbnail_map
    pass_query_params
    id = params[:id].to_s
    if @user
      @user.update_attribute(:thumbnail_maps, false)
      flash_notice(:show_observation_thumbnail_map_hidden.t)
    else
      session[:hide_thumbnail_maps] = true
    end
    redirect_with_query(permanent_observation_path(id: id))
  end
end

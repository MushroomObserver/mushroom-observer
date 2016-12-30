# encoding: utf-8
#
#  = AJAX Controller
#
#  AJAX controller can take slightly "enhanced" URLs:
#
#    http://domain.org/ajax/method
#    http://domain.org/ajax/method/id
#    http://domain.org/ajax/method/type/id
#    http://domain.org/ajax/method/type/id?other=params
#
#  Syntax of successful responses vary depending on the method.
#
#  Errors are status 500, with the response body being the error message.
#  Semantics of the possible error messages varies depending on the method.
#
#  == Actions
#
#  api_key::          Activate and edit ApiKey's.
#  auto_complete::    Return list of strings matching a given string.
#  exif::             Get EXIF header info of an image.
#  export::           Change export status.
#  external_link::    Add, edit and remove external links assoc. with obs.
#  geocode::          Look up extents for geographic location by name.
#  old_translation::  Return an old TranslationString by version id.
#  pivotal::          Pivotal requests: look up, vote, or comment on story.
#  vote::             Change vote on proposed name or image.
#
#  get_multi_image_template:: HTML template for uploaded image.
#  create_image_object::      Uploads image without observation yet.
#
class AjaxController < ApplicationController
  include AjaxController::ApiKey
  include AjaxController::AutoComplete
  include AjaxController::Exif
  include AjaxController::Export
  include AjaxController::ExternalLink
  include AjaxController::Geocode
  include AjaxController::OldTranslation
  include AjaxController::Pivotal
  include AjaxController::UploadImage
  include AjaxController::Vote

  disable_filters
  around_action :catch_ajax_errors
  layout false

  def catch_ajax_errors
    prepare_parameters
    yield
  rescue => e
    msg = e.to_s + "\n"
    msg += backtrace(e) if Rails.env != "production"
    render(text: msg, status: 500)
  end

  def prepare_parameters
    @type  = params[:type].to_s
    @id    = params[:id].to_s
    @value = params[:value].to_s
  end

  def backtrace(e)
    msg = ""
    e.backtrace.each do |line|
      return msg if line =~ /action_controller.*perform_action/
      msg += line + "\n"
    end
  end

  def session_user!
    User.current = get_session_user
    raise "Must be logged in." unless User.current
  end

  # Used by unit tests.
  def test
    render(text: "test")
  end
end

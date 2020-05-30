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
#  create_image_object::  Uploads image without observation yet.
#  exif::             Get EXIF header info of an image.
#  export::           Change export status.
#  external_link::    Add, edit and remove external links assoc. with obs.
#  multi_image_template:: HTML template for uploaded image.
#  old_translation::  Return an old TranslationString by version id.
#  pivotal::          Pivotal requests: look up, vote, or comment on story.
#  vote::             Change vote on proposed name or image.
#
class AjaxController < ApplicationController
  require_dependency "ajax_controller/api_key"
  require_dependency "ajax_controller/auto_complete"
  require_dependency "ajax_controller/exif"
  require_dependency "ajax_controller/export"
  require_dependency "ajax_controller/external_link"
  require_dependency "ajax_controller/old_translation"
  require_dependency "ajax_controller/pivotal"
  require_dependency "ajax_controller/upload_image"
  require_dependency "ajax_controller/vote"

  disable_filters
  around_action :catch_ajax_errors
  layout false

  def catch_ajax_errors
    prepare_parameters
    yield
  rescue StandardError => e
    msg = e.to_s + "\n"
    msg += backtrace(e) if Rails.env.production?
    render(plain: msg, status: :internal_server_error)
  end

  def prepare_parameters
    @type  = params[:type].to_s
    @id    = params[:id].to_s
    @value = params[:value].to_s
  end

  def backtrace(exception)
    result = ""
    exception.backtrace.each do |line|
      break if /action_controller.*perform_action/.match?(line)

      result += line + "\n"
    end
    result
  end

  def session_user!
    User.current = session_user || raise("Must be logged in.")
  end

  # Used by unit tests.
  def test
    render(plain: "test")
  end
end

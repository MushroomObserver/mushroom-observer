# encoding: utf-8
#
#  = API Controller
#
#  This controller handles the JSON and XML interfaces
#
#  == Actions
#
#  observations, etc.::   Entry point for REST requests.
#
################################################################################
#
class ApiController < ApplicationController
  require "xmlrpc/client"
  require_dependency "api"

  disable_filters

  # wrapped parameters break JSON requests in the unit tests.
  wrap_parameters false

  # Standard entry point for REST requests.
  def api_keys
    rest_query(:api_key)
  end

  def comments
    rest_query(:comment)
  end

  def external_links
    rest_query(:external_link)
  end

  def images
    rest_query(:image)
  end

  def locations
    rest_query(:location)
  end

  def names
    rest_query(:name)
  end

  def observations
    rest_query(:observation)
  end

  def projects
    rest_query(:project)
  end

  def sequences
    rest_query(:sequence)
  end

  def species_lists
    rest_query(:species_list)
  end

  def users
    rest_query(:user)
  end

  ##############################################################################

  private

  def rest_query(type)
    @start_time = Time.zone.now
    args = params_to_api_args(type)

    if request.method == "POST"
      args[:upload] = upload_api if something_to_post?
      # Special exception to let caller who creates new user to see that user's
      # new API keys.  Otherwise there is no way to get that info via the API.
      @show_api_keys_for_new_user = true if type == :user
    end

    render_api_results(args)
  end

  # Massage params hash to proper args hash for api
  def params_to_api_args(type)
    args = params.to_hash.symbolize_keys.except(:controller)
    args[:method] = request.method
    args[:action] = type
    args.delete(:format) if Rails.env == "test"
    args
  end

  def something_to_post?
    # in Rails 4.x was:
    # upload_length > 0 && upload_type.present?
    # But in 5.x, upload_type seems to always be present because
    # request.headers["CONTENT_TYPE"] == "application/x-www-form-urlencoded"
    # I tried the following but they didn't help:
    #     config.action_dispatch.default_headers["CONTENT_TYPE"] = ""
    # in config/environments/test.rb;
    # Also, for the failing methods in ApiControllerTest,
    #   process(:observations, ... as: nil)
    # instead of
    #   post(:observations ...)
    upload_length > 0 && upload_type.present? &&!upload_data.nil?
  end

  def upload_api
    API::Upload.new(
      data:         upload_data,
      length:       upload_length,
      content_type: upload_type,
      checksum:     request.headers["CONTENT_MD5"].to_s
    )
  end

  def upload_length
    testing? ? request.headers["CONTENT_LENGTH"].to_i : request.content_length
  end

  def upload_type
    testing? ? request.headers["CONTENT_TYPE"].to_s : request.media_type
  end

  def upload_data
    testing? ? request.headers["RAW_POST_DATA"] : request.body
  end

  # convenience method to shorten lines (also helps to trick Coveralls)
  def testing?
    Rails.env == "test"
  end

  def render_api_results(args)
    @api = API.execute(args)
    User.current = @user = @api.user
    do_render
  rescue => e
    @api ||= API.new
    @api.errors << API::RenderFailed.new(e)
    do_render
  end

  def do_render
    # need to default to xml for backwards compatibility
    request.format = "xml" if request.format == "html"
    respond_to do |format|
      format.xml  { do_render_xml  }
      format.json { do_render_json }
    end
  end

  def do_render_xml
    render(layout: false, template: "/api/results")
  end

  def do_render_json
    render(layout: false, template: "/api/results")
  end
end

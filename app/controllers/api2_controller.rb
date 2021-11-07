# frozen_string_literal: true

#
#  = API2 Controller
#
#  This controller handles the JSON and XML interfaces
#
#  == Actions
#
#  observations, etc.::   Entry point for REST requests.
#
################################################################################
#
class Api2Controller < ApplicationController
  require "xmlrpc/client"
  require_dependency "api"

  disable_filters

  # wrapped parameters break JSON requests in the unit tests.
  wrap_parameters false

  # Standard entry point for REST requests.
  def api_keys
    rest_query(:api_key)
  end

  def collection_numbers
    rest_query(:collection_number)
  end

  def comments
    rest_query(:comment)
  end

  def external_links
    rest_query(:external_link)
  end

  def external_sites
    rest_query(:external_site)
  end

  def herbaria
    rest_query(:herbarium)
  end

  def herbarium_records
    rest_query(:herbarium_record)
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
      if args[:upload].present?
        args[:upload] = upload_from_multipart_form_data(args[:upload])
      elsif is_request_body_an_upload?
        args[:upload] = upload_from_request_body
      end
      # Special exception to let caller who creates new user to see that user's
      # new API keys.  Otherwise there is no way to get that info via the API.
      @show_api_keys_for_new_user = true if type == :user
    end

    render_api_results(args)
  end

  # Massage params hash to proper args hash for api
  def params_to_api_args(type)
    args = params.to_unsafe_h.symbolize_keys.except(:controller)
    args[:method] = request.method
    args[:action] = type
    args.delete(:format)
    args
  end

  def upload_from_multipart_form_data(data)
    API2::Upload.new(data: data)
  end

  def is_request_body_an_upload?
    (request.content_length.positive? &&
     request.media_type.present? &&
     request.media_type != "application/x-www-form-urlencoded" &&
     request.media_type != "multipart/form-data" &&
     request.body.present?)
  end

  def upload_from_request_body
    API2::Upload.new(
      data: request.body,
      length: request.content_length,
      content_type: request.media_type,
      checksum: request.headers["CONTENT_MD5"].to_s
    )
  end

  def render_api_results(args)
    @api = API2.execute(args)
    User.current = @user = @api.user
    do_render
  rescue StandardError => e
    @api ||= API2.new
    @api.errors << API2::RenderFailed.new(e)
    do_render
  end

  def do_render
    set_cors_headers
    request.format = "json" if request.format == "html"
    respond_to do |format|
      format.xml  { do_render_xml  }
      format.json { do_render_json }
    end
  end

  def do_render_xml
    render(layout: false, template: "/api2/results")
  end

  def do_render_json
    render(layout: false, template: "/api2/results")
  end

  def set_cors_headers
    return unless request.method == "GET"

    response.set_header("Access-Control-Allow-Origin", "*")
    response.set_header("Access-Control-Allow-Headers",
                        "Origin, X-Requested-With, Content-Type, Accept")
    response.set_header("Access-Control-Allow-Methods", "GET")
  end
end

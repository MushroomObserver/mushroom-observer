# encoding: utf-8
#
#  = API Controller
#
#  This controller handles the XML interface.
#
#  == Actions
#
#  xml_rpc::              Entry point for XML-RPC requests.
#  observations, etc.::   Entry point for REST requests.
#
################################################################################

class ApiController < ApplicationController
  require 'xmlrpc/client'
  # require_dependency 'classes/api'

  disable_filters

  # Standard entry point for REST requests.
  def api_keys;      rest_query(:api_key);      end
  def comments;      rest_query(:comment);      end
  def images;        rest_query(:image);        end
  def locations;     rest_query(:location);     end
  def names;         rest_query(:name);         end
  def observations;  rest_query(:observation);  end
  def projects;      rest_query(:project);      end
  def species_lists; rest_query(:species_list); end
  def users;         rest_query(:user);         end

  def rest_query(type)
    @start_time = Time.now

    # Massage params into a proper set of args.
    args = {}
    for key in params.keys
      args[key.to_sym] = params[key]
    end
    args.delete(:controller)
    args[:method] = request.method
    args[:action] = type

    if TESTING
      post_data      = request.headers['RAW_POST_DATA']
      content_length = request.headers['CONTENT_LENGTH'].to_i
      content_type   = request.headers['CONTENT_TYPE'].to_s
      content_md5    = request.headers['CONTENT_MD5'].to_s
      if request.method == "POST" && content_length > 0 && !content_type.blank?
        args[:upload] = API::Upload.new(
          data:         post_data,
          length:       content_length,
          content_type: content_type,
          checksum:     content_md5
        )
      end
    else
      if request.method == "POST" && request.content_length > 0 && !request.media_type.blank?
        args[:upload] = API::Upload.new(
          data:         request.body,
          length:       request.content_length,
          content_type: request.media_type,
          checksum:     request.headers['CONTENT_MD5'].to_s
        )
      end
    end

    # Special exception to allow caller who creates new user to see that user's
    # new API keys.  Otherwise there is no way to get that info via the API. 
    if request.method == "POST" and type == :user
      @show_api_keys_for_new_user = true
    end

    render_api_results(args)
  end

  def render_api_results(args)
    @api = API.execute(args)
    User.current = @user = @api.user
    if @api.errors.any?(&:fatal)
      render_xml(:layout => 'api', :text => '')
    else
      render_xml(:layout => 'api', :template => '/api/results')
    end
  rescue => e
    @api ||= API.new
    @api.errors << API::RenderFailed.new(e)
    render_xml(:layout => 'api', :text => '')
  end
end

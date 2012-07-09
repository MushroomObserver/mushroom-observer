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

require 'xmlrpc/client'
require_dependency 'classes/api'

class ApiController < ApplicationController
  disable_filters

  # Standard entry point for XML-RPC requests.
  # def xml_rpc
  #   begin
  #     @@xmlrpc_reader ||= XMLRPC::XMLParser::REXMLStreamParser.new
  #     method, args = @@xmlrpc_reader.parseMethodCall(request.content)
  #     if (args.length != 1) or
  #        !args[0].is_a?(Hash)
  #       raise "Invalid request; expecting a single hash of named parameters."
  #     end
  #     args = args.first
  #     args[:method] = method
  #     xact = Transaction.new(args)
  #     xact.validate_args
  #     @api = xact.execute
  #     render_api_results
  #   rescue => e
  #     @api = API.new
  #     @api.errors << API::RenderFailed.new(e)
  #     render_api_results
  #   end
  # end

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
    args[:http_request] = request if request.content_length.to_i > 0

    # Special exception to allow caller who creates new user to see that user's
    # new API keys.  Otherwise there is no way to get that info via the API. 
    if request.method == :post and type == :user
      @show_api_keys_for_new_user = true
    end

    render_api_results(args)
  end

  def render_api_results(args)
    @api = API.execute(args)
    headers['Content-Type'] = 'application/xml'
    User.current = @user = @api.user
    if @api.errors.any?(&:fatal)
      render(:layout => 'api', :text => '')
    else
      render(:layout => 'api', :template => '/api/results.rxml')
    end
  rescue => e
    @api.errors << API::RenderFailed.new(e)
    render(:layout => 'api', :text => '')
  end
end

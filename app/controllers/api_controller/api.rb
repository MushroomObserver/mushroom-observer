# encoding: utf-8
#
#  = API Stuff
#
#  == Actions
#
#  xml_rpc::    Entry point for XML-RPC requests.
#  <table>::    Entry point for RESTful requests.
#
#  == Methods
#
#  render_results::   Render results (same for both entry points).
#
################################################################################

require 'xmlrpc/client'

class ApiController
  # ----------------------------
  #  XML-RPC
  # ----------------------------

  # Standard entry point for XML-RPC requests.
  def xml_rpc
    begin
      @@xmlrpc_reader ||= XMLRPC::XMLParser::REXMLStreamParser.new
      method, args = @@xmlrpc_reader.parseMethodCall(request.content)
      if (args.length != 1) or
         !args[0].is_a?(Hash)
        raise "Invalid request; expecting a single hash of named parameters."
      end
      args = args.first
      args[:method] = method
      # args[:_safe] = false
      xact = Transaction.new(args)
      xact.validate_args
      api = xact.execute
      render_results(api)
    rescue => e
      api = API.new
      @errors = api.convert_error(e, 501, nil, true)
      render_results(api)
    end
  end

  # ----------------------------
  #  REST
  # ----------------------------

  # Standard entry point for REST requests.
  def comments;      rest_query(:comment);      end
  def images;        rest_query(:image);        end
  def interests;     rest_query(:interest);     end
  def licenses;      rest_query(:license);      end
  def locations;     rest_query(:location);     end
  def names;         rest_query(:name);         end
  def namings;       rest_query(:naming);       end
  def notifications; rest_query(:notification); end
  def observations;  rest_query(:observation);  end
  def projects;      rest_query(:project);      end
  def species_lists; rest_query(:species_list); end
  def synonyms;      rest_query(:synonym);      end
  def user_groups;   rest_query(:user_group);   end
  def users;         rest_query(:user);         end
  def votes;         rest_query(:vote);         end

  def rest_query(type)
    @start_time = Time.now

    # Massage params into a proper set of args.
    args = {}
    for key in params.keys
      args[key.to_sym] = params[key]
    end
    args.delete(:controller)
    args[:method] = request.method.to_s
    args[:action] = type.to_s
    args[:http_request_body] = request if request.content_length.to_i > 0
    # args[:_safe] = false

    api = API.execute(args)
    render_results(api)
  end

  def render_results(api)
    headers['Content-Type'] = 'application/xml'

    @objects = api.results
    @errors  = api.errors
    @user    = api.user
    @query   = api.query
    @detail  = api.detail
    @number  = api.number
    @page    = api.page
    @pages   = api.pages
    @version = api.version

    begin
      if [:get, :post].include?(request.method)
        render(:layout => 'api', :template => '/api/results.rxml')
      else
        render(:layout => 'api', :text => '')
      end
    rescue => e
      @errors << api.convert_error(e, 501, nil, true)
      render(:layout => 'api', :text => '')
    end
  end
end

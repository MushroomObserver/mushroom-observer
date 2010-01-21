################################################################################
#
#  This controller handles the XML interface.
#
<<<<<<< .mine
=======
#  All request types use a single URL for each object class.  Thus, searching
#  for, updating, destroying, and creating observations use:
#
#    GET    http://mo.org/api/observations       Search for observations.
#    PUT    http://mo.org/api/observations       Modify observations.
#    DELETE http://mo.org/api/observations       Destroy observations.
#    POST   http://mo.org/api/observations       Create a new observation.
#
#  GET, PUT and DELETE requests all take the same "search" parameters, e.g.:
#
#    GET http://mo.org/api/observations/12345
#    GET http://mo.org/api/observations?user=jason
#    GET http://mo.org/api/observations?date=20090101-20100101
#
#  GET requests return information about matching objects.  DELETE requests
#  attempt to destroy all matching objects.  PUT requests allow users to make
#  one or more changes to all matching objects.  Changes are specified with
#  "set" parameters, e.g.:
#
#    PUT http://mo.org/api/observations/12345?set_date=20090731
#    PUT http://mo.org/api/observations?user=jason&date=20091201&set_specimen=true
#
#  (The former changes the date on observation #12345; the latter informs MO
#  that specimens are available for all of Jason's observations on 20091201.)
#
#  POST requests attempt to create a new object and return the same information
#  a GET request of that single id would return (or an error message).
#
#  Only certain request types are allowed for certain objects.  This is
#  determined by the presence of methods called "get_user", "delete_name",
#  "put_observation", "post_comment", etc.  The calling syntax for each is
#  described below.
#
#  The "get_xxx" methods are responsible for parsing the "search" parameters
#  and returning enough information to create a SQL query.  For example,
#
#    get_observation() returns [conditions, tables, joins, max_num_per_page]
#
#  The "put_xxx" methods are responsible for parsing the "set" parameters and
#  returning a hash that will be passed into object.write_attributes. 
#
#    assigns =
#      put_observation()
#
#  The "delete_xxx" methods do nothing.  They are never called; it's only
#  important that they *exist*.
#
#  The "post_xxx" methods parse the necessary arguments, create the object,
#  and return the resulting object.  They raise errors if anything goes wrong.
#
>>>>>>> .r713
#  Views:
#    xml_rpc        Entry point for XML-RPC requests.
#    <table>        Entry point for REST requests.
#
################################################################################

class ApiController < ApplicationController

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

  def xml_rpc
    xact = Transaction.new(:query => request.content)
    xact.args[:_safe] = false
    api = xact.process
    render_results(api)
  end

protected

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
    args[:_safe] = false

    api = API.execute(args)
    render_results(api)
  end

  def render_results(api)
    @objects = api.objects
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
        render(:layout => 'api')
      else
        render(:layout => 'api', :text => '')
      end
    rescue => e
      @errors << api.convert_error(e, 501, nil, true)
      render(:layout => 'api', :text => '')
    end
  end
end

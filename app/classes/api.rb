#
#  = API
#
#  == Overview
#
#  All requests return an array of objects affected, and an array of errors:
#
#    request = {
#      :method => :get,
#      :action => :name,
#      :id     => 1234,
#      ...
#    }
#
#    api = API.execute(request)
#    objects = api.objects
#    errors  = api.errors
#    args    = api.args
#
#  The errors are of the MoApiException class, and include code, message and
#  a flag indicating whether the error was fatal or not.  Example:
#
#    error.code  => 102
#    error.title => 'bad request syntax'
#    error.msg   => 'missing action parameter'
#    error.fatal => true
#
#  There are only a few basic +method+ types, mostly corresponding to the HTML
#  request methods:
#
#    :method => 'get'      Look up information.
#    :method => 'put'      Modify object(s).
#    :method => 'post'     Create new object(s).
#    :method => 'delete'   Destroy existing object(s).
#
#  The +action+ argument specifies the type of data you're interested in.
#  Every table in the database has a corresponding action with the same name.
#
#    :method => 'get', :action => 'observation'  Searches for observations.
#    :method => 'put', :action => 'location'     Modifies location(s).
#    :method => 'post', :action => 'name'        Creates a new name.
#    :method => 'delete', :action => 'image'     Deletes one or more image(s).
#
#  GET, PUT and DELETE requests all take the same "search" parameters, e.g.:
#
#    :id => 12345                       Specifies object #12345.
#    :user => 'fred'                    Specifies all objects owned by Fred.
#    :date => '20090101-20100101'       Specifies all objects created in 2009.
#
#  Multiple search conditions are combined intersectively, i.e. cond_1 AND
#  cond2 AND ...  Unions must be constructed with multiple queries.
#
#  GET requests return an array of matching objects.  DELETE requests attempt
#  to destroy all matching objects.  PUT requests allow users to make one or
#  more changes to all matching objects.  Changes are specified with "set"
#  parameters, e.g.:
#
#    :set_date => '20090731'            Change observation date to 20090731.
#    :set_location => 'California'      Change location (can also take ID).
#    :set_specimen => 'true'            Tell it that you have a specimen.
#
#  Multiple set parameters are allowed, in which case it attempts to make each
#  of the changes to all matching objects.
#
#  POST requests attempt to create a new object and return the resulting
#  object.  Creating multiple objects requires multiple requests.
#
#  Authentication for PUT, POST, DELETE methods is currently accomplished by
#  requiring +auth_id+ and +auth_code+ arguments:
#
#    :auth_id    => user.id
#    :auth_code  => user.auth_code     # (same as is stored in autologin cookie)
#    :auth_admin => true               # (turn on "admin mode" for admins only)
#
#  To find a full list of arguments allowed for each pair of (method, action)
#  look at the documentation for +method_action+, for example:
#
#    get_user               Method used to GET users.
#    put_name               Method used to PUT names.
#    post_observation       Method used to POST observations.
#    delete_image           Method used to DELETE images.
#
#  == Internals
#
#  Only certain request types are allowed for certain objects.  This is
#  determined by the presence of the methods mentioned above called "get_user",
#  "delete_name", "put_observation", "post_comment", etc.  The calling syntax
#  for each is described in the section headings.
#
#  The "get_xxx" methods are responsible for parsing the "search" parameters
#  and returning enough information to create a SQL query.
#
#  The "put_xxx" methods are responsible for parsing the "set" parameters and
#  returning a hash that will be passed into object.write_attributes.
#
#  The "delete_xxx" methods are responsible for destroying a single object,
#  returning true on success.
#
#  The "post_xxx" methods parse the necessary arguments, then create and return
#  the resulting object.  They raise errors if anything goes wrong.
#
#  == Attributes
#
#  args::                 Original hash of arguments passed in.
#  objects::              List of objects found / modified (after +process+).
#  errors::               List of errors (after +process+).
#  user::                 Authenticated user making request.
#  query::                Rough copy of SQL query used.
#  detail::               Level of detail requested in XML response.
#  number::               Number of matching objects.
#  page::                 Current page number.
#  pages::                Number of pages available.
#  version::              Version number of this API.
#
#  == Class methods
#
#  new::                  Create new request (but don't process).
#  execute::              Create and process a new request.
#
#  == Instance methods
#
#  process::              Process a request.
#
#  ==== GET methods
#
#  get_comment::          Find comment(s).
#  get_image::            Find image(s).
#  get_license::          Find license(s).
#  get_location::         Find location(s).
#  get_name::             Find name(s).
#  get_naming::           Find naming(s).
#  get_observation::      Find observation(s).
#  get_user::             Find user(s).
#  get_vote::             Find vote(s).
#
#  ==== PUT methods
#
#  put_comment::          Modify comment(s).
#  put_image::            Modify image(s).
#  put_naming::           Modify naming(s).
#  put_observation::      Modify observation(s).
#  put_vote::             Modify vote(s).
#
#  ==== DELETE methods
#
#  delete_comment::       Destroy comment(s).
#  delete_image::         Destroy image(s).
#  delete_naming::        Destroy naming(s).
#  delete_observation::   Destroy observation(s).
#  delete_vote::          Destroy vote(s).
#
#  ==== POST methods
#
#  post_comment::         Create a comment.
#  post_image::           Create a image.
#  post_location::        Create a location.
#  post_name::            Create a name.
#  post_naming::          Create a naming.
#  post_observation::     Create a observation.
#  post_vote::            Create a vote.
#
#  ==== Other request methods
#
#  login_user::           Report that user just logged in.
#  logout_user::          Report that user just logged out.
#
#  ==== Parsers
#
#  parse_arg::            Grab argument (name is a Symbol).
#  parse_page::           Parse page number.
#  parse_page_len::       Parse page length.
#  parse_boolean::        Parse boolean.
#  parse_integer::        Parse integer.
#  parse_float::          Parse floating point.
#  parse_vote::           Parse confidence level.
#  parse_string::         Parse string (optional max length).
#  parse_date::           Parse date.
#  parse_object::         Parse object by id, return instance.
#  parse_object_id::      Parse object by id, return id.
#  parse_objects::        Parse one or more objects by id, return instances.
#  parse_enum::           Parse enumerated string.
#  parse_rank::           Parse name rank ('Genus', 'Species', etc.)
#
#  ==== SQL builders
#
#  sql_id::               SQL for one or more objects specified by id/sync_id.
#  sql_id_or_name::       SQL for one or more objects specified by id/sync_id and/or name.
#  sql_date::             SQL for date. [will accept date range eventually]
#  sql_time::             SQL for date-time. [will accept range eventually]
#  sql_search::           SQL for searching for a string. [will accept wildcards eventually]
#  uses_table?::          Checks if a snippet of SQL uses a given table.
#  build_sql::            Builds a SQL snippet using ActiveRecord's sanitize_sql.
#
#  ==== Other stuff
#
#  error::                Create an MoApiException.
#  convert_error::        Convert arbitrary exception into an MoApiException.
#  authenticate::         Make sure user is authenticated.
#  error_if_any_other_args::
#                         Add errors for all unused errors.
#  make_sure_found_all_objects::
#                         If searching by id alone, raise errors for
#                         any id explicitly listed that wasn't found.
#  load_from_url::        Loads a file from a given URL via HTTP.
#
#  == Undocumented Arguments
#
#  There are a few subtle ways in which requests via +api_controller.rb+ differ
#  from requests via Transaction logging and remote server synchronization.
#  Certain "unsafe" operations must be allowed for the latter that we don't
#  want random User's to have access to.
#
#  _safe::      Did this request come from a trusted source?
#  _user::      User that sent safe request.
#  _time::      Time safe request was sent.
#  id::         In safe POST requests, use +id+ to explicitly set the sync_id.
#
################################################################################

class API

  # Copy of the Hash of args you passed in.
  attr_accessor :args

  # Array of objects returned.
  attr_accessor :objects

  # Array of MoApiException instances returned.
  attr_accessor :errors

  # User used to authenticate (if any).
  attr_accessor :user

  # Is this request from a "trusted" source (e.g., sync job or admin)?
  attr_accessor :safe

  # Time this request was made (possibly old if from sync job).
  attr_accessor :time

  # SQL query used (if any) to look up objects.
  attr_accessor :query

  # SQL query used (if any) to count results (without pagination).
  attr_accessor :count_query

  # What level of detail requested in response: :none, :low, :high
  attr_accessor :detail

  # Number of objects that match query (if applicable).
  attr_accessor :number

  # Page number returned (if paginated).
  attr_accessor :page

  # Number of pages of results available.
  attr_accessor :pages

  # Name of the database table corresponding to +method+.
  attr_accessor :table

  # Model class corresponding to +method+.
  attr_accessor :model

  # Version, in case we change arg syntax significantly at some later time.
  API_VERSION = '1.0'
  def self.version; API_VERSION; end
  def version; API_VERSION; end

  ##############################################################################
  #
  #  :section: Public interface.
  #
  ##############################################################################

  # Set up a new query.
  #
  #   api = API.new(:method => :get, :action => :user, :id => 252)
  #   api.process
  #   user = api.objects.first
  #
  def initialize(args={})
    self.args = args
  end

  # Convenience wrapper: instantiate and execute query.  Returns API instance.
  #
  #   api = API.execute(:method => :get, :action => :user, :id => 252)
  #   user = api.objects.first
  #
  def self.execute(args)
    api = self.new(args)
    api.process
    return api
  end

  # Main entry point: execute a query.  Returns list of objects and errors.
  #
  #   api = API.new(:method => :get, :action => :user, :name => 'fred')
  #   objects, errors = api.process
  #
  # See class documentation for more information on query syntax.  Also note
  # that lots of extra information is available through the API instance:
  #
  #   api.args      Copy of the Hash of args you passed in.
  #   api.objects   Array of objects returned.
  #   api.errors    Array of MoApiException instances returned.
  #   api.user      User used to authenticate (if any).
  #   api.query     Basic SQL query used (if any).  (For info purposes only.)
  #   api.detail    What level of detail requested in response: :none, :low, :high
  #   api.number    Number of objects that match query (if applicable).
  #   api.page      Page number returned (if paginated).
  #   api.pages     Number of pages of results available.
  #
  def process
    self.objects = []
    self.errors  = []

    # Get request method and action.
    raise error(101, "Missing method.") unless method = parse_arg(:method)
    raise error(102, "Missing action.") unless action = parse_arg(:action)
    method = method.to_s.downcase.to_sym
    action = action.to_s.downcase.to_sym
    if !respond_to?("#{method}_#{action}")
      raise error(101, "#{method.to_s.upcase} method not available for #{action}.")
    end

    # Converts :species_list to "species_lists" and the class SpeciesList.
    self.table = action.to_s.pluralize
    self.model = action.to_s.camelize.constantize

    # Which mode are we running in?
    #  safe - Trusted or admin mode.
    #  user - User making request.
    #  time - Time request was made.
    if self.safe = parse_boolean(:_safe)
      self.user = User.safe_find(parse_integer(:_user))
      self.time = parse_time(:_time)
    else
      self.safe = parse_boolean(:auth_admin) if user && user.admin
      self.user = authenticate(method != :get)
      self.time = Time.now
    end
    User.current = user

    # Process specific method.
    send("process_#{method}")
    [objects, errors]

  rescue => e
    errors << convert_error(e, 501, e.to_s, true)
    [objects, errors]
  end

  # POST method: create one object.
  def process_post
    must_authenticate
    objects << send("post_#{action}")
  end

  # GET method: look up existing objects.
  def process_get
    # Parse query arguments.
    conds, tables, joins, max_page_len = send("get_#{action}")

    # Let user request detail level.
    self.detail = parse_enum(:detail, [:none, :low, :high]) || :none

    # Paginate results.
    self.page = parse_page
    page_len = parse_page_len(max_page_len)
    error_if_any_other_args

    # Look up results and make sure none are missing.
    create_lookup_query(conds, tables, joins, page_len)
    instantiate_results(detail == :high ? joins : nil)

    # Count total number of results available.
    if page > 1 || ids.length >= page_len
      self.number = model.connection.select_value(count_query).to_i
      self.pages  = (number.to_f / page_len).ceil
    else
      self.number = ids.length
      self.pages  = 1
    end
  end

  # PUT method: look up existing objects and apply a set of changes to them.
  def process_put
    self.page   = nil
    self.detail = :none

    # Get array of values to change.
    setter = send("put_#{action}")
    sets[:modified] = Time.now

    # Parse query arguments.
    conds, tables, joins, max_page_len = send("get_#{action}")
    error_if_any_other_args

    # Look up results and make sure none are missing.
    create_lookup_query(conds, tables, joins)
    instantiate_results

    # Apply updates to all matching objects.
    new_objects = objects.map do |obj|
      begin
        setter.call(obj)
        obj
      rescue => e
        errors << convert_error(e, 203, "error updating #{action} ##{id}")
        obj
      end
    end
    # (In case any updates caused merges.)
    self.objects = new_objects
  end

  # DELETE method: look up existing objects and destroy them.
  def process_delete
    self.page   = nil
    self.detail = :none

    # Parse query arguments.
    conds, tables, joins, max_page_len = send("get_#{action}")
    error_if_any_other_args

    # Look up results and make sure none are missing.
    create_lookup_query(conds, tables, joins, page_len)
    instantiate_results

    # Delete matching objects.
    objects.each do |x|
      id = x.id
      begin
        send("delete_#{action}", x)
      rescue => e
        errors << convert_error(e, 204, "error destroying #{action} ##{id}")
      end
    end
  end

  # Create SQL query to count matching results, and to return result ids.
  # Arguments come from +get_<model>+ method.  Fills in +query+ and
  # +count_query+ instance variables.
  def create_lookup_query(conds, tables, joins, page_len=nil) # :nodoc:
    tables.unshift(table)
    tables = "FROM #{tables.join(', ')}"
    conds = "WHERE #{conds.join(' AND ')}"
    conds = '' if conds == 'WHERE '
    limit = page_len ? "LIMIT #{(page-1)*page_len}, #{page_len}" : ''
    self.count_query = "SELECT COUNT(DISTINCT #{table}.id) #{tables} #{conds}"
    self.query = "SELECT DISTINCT #{table}.id #{tables} #{conds} #{limit}"
  end

  # Execute query and instantiate results.  Pass in include-style arguments if
  # you want eager-loading.  Sets the +objects+ instance variable.
  def instantiate_results(joins=nil) # :nodoc:
    ids = model.connection.select_values(query)
    make_sure_found_all_objects(ids, action)
    self.objects = joins ?
      model.all(:conditions => ['id in (?)', ids], :include => joins) :
      model.all(:conditions => ['id in (?)', ids])
  end

  ##############################################################################
  #
  #  :section: GET Methods
  #
  #  These are responsible for parsing the "search" parameters and returning
  #  all the information necessary to create a SQL query.  In particular, they
  #  must each return four things:
  #
  #  conditions::   Array of SQL fragments that form the "WHERE" clause.
  #  tables::       Array of tables used in +conditions+.
  #  joins::        Array of tables to :include when instantiating results (if eager-loading).
  #  max_page_len:: Maximum number of objects per page user is allowed to request.
  #
  #  Parsing is all done using several helper methods.  Here are some:
  #
  #  sql_id::       One or more ids or sync_ids.
  #  sql_date::     One or more dates or date ranges.
  #  sql_search::   Search pattern (only one allowed).
  #
  #  All of these return SQL fragments that encode the given condition(s).
  #
  #  Another handy method is:
  #
  #  uses_table?::  Does an SQL string use a given table?
  #
  #  This can be used to determine which additional tables need to be joined to
  #  in order to execute the given SQL query.
  #
  ##############################################################################

  def get_comment
    conds  = []
    tables = []
    joins  = [:user]

    conds += sql_date(:created, 'comments.created')
    conds += sql_date(:modified, 'comments.modified')
    conds += sql_id_or_name(:user, 'comments.user_id', 'users.login', 'users.name')
    conds += sql_enum(:object_type, 'comments.object_type')
    conds += sql_id(:object_id, 'comments.object_id')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'comments.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = comments.user_id'
    end

    return [conds, tables, joins, 1000]
  end

  def get_image
    conds  = []
    tables = []
    joins  = [:user, :license]

    conds += sql_date(:created, 'images.created')
    conds += sql_date(:modified, 'images.modified')
    conds += sql_id_or_name(:user, 'images.user_id', 'users.login', 'users.name')
    conds += sql_id_or_name(:name, 'observations.name_id', 'names.text_name', 'names.search_name')
    conds += sql_id(:observation, 'images_observations.observation_id')
    conds += sql_id(:license, 'images.license_id')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'images.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = images.user_id'
    end
    if uses_table?(conds, 'names')
      tables << :names
      tables << :observations
      tables << :images_observations
      conds  << 'observations.name_id = names.id'
      conds  << 'images_observations.observation_id = observations.id'
      conds  << 'images_observations.image_id = images.id'
    elsif uses_table?(conds, 'observations')
      tables << :observations
      tables << :images_observations
      conds  << 'images_observations.observation_id = observations.id'
      conds  << 'images_observations.image_id = images.id'
    elsif uses_table?(conds, 'images_observations')
      tables << :images_observations
      conds  << 'images_observations.image_id = images.id'
    end

    return [conds, tables, joins, 100]
  end

  def get_interest
    conds  = []
    tables = []
    joins  = [:object]

    raise error(303, "must login to process your interests") if !user
    conds += build_sql(["interests.user_id = ?", user.id])
    conds += sql_date(:created, 'interests.created')
    conds += sql_date(:modified, 'interests.modified')
    conds += sql_enum(:object_type, 'interests.object_type',
                      [ :location, :name, :obsercation ])
    conds += sql_id(:object_id, 'interests.object_id')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'interests.id')

    return [conds, tables, joins, 1000]
  end

  def get_license
    conds  = []
    tables = []
    joins  = []

    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'licenses.id')

    return [conds, tables, joins, 1000]
  end

  def get_location
    conds  = []
    tables = []
    joins  = []

    conds += sql_id_or_name(:creator, 'locations.user_id', 'users.login', 'users.name')
    conds += sql_id(:editor, 'locations_versions.user_id')
    conds += sql_date(:created, 'locations.created')
    conds += sql_date(:modified, 'locations.modified')
    conds += sql_search(:name, 'locations.display_name', 'locations.search_name')
    # conds += sql_xxx(:latitude, 'locations.north', 'locations.south')
    # conds += sql_xxx(:longitude, 'locations.west', 'locations.east')
    # conds += sql_xxx(:elevation, 'locations.high', 'locations.low')
    conds += sql_boolean(:has_description, '(locations.description_id NOT NULL)')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'locations.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds  << 'users.id = locations.user_id'
    end
    if uses_table?(conds, 'locations_versions')
      tables << :locations_versions
      conds  << 'locations_versions.location_id = locations.id'
    end

    return [conds, tables, joins, 1000]
  end

  def get_location_description
    conds  = []
    tables = []
    joins  = []

    # conds += sql_xxx(:author, xxx)
    # conds += sql_xxx(:editor, xxx)
    conds += sql_date(:created, 'location_descriptions.created')
    conds += sql_date(:modified, 'location_descriptions.modified')
    conds += sql_id_or_name(:location, 'location_descriptions.location_id', 'locations.display_name', 'locations.search_name')
    conds += sql_enum(:source_type, 'location_descriptions.source_type', Description.all_source_types)
    conds += sql_search(:source_name, 'location_descriptions.source_name')
    conds += sql_boolean(:public, 'location_descriptions.public')
    conds += sql_id(:license, 'location_descriptions.license_id')
    conds += sql_search(:search, LocationDescription.all_note_fields.map {|x| "location_descriptions.#{x}"})
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'location_descriptions.id')

    return [conds, tables, joins, 1000]
  end

  def get_name
    conds  = []
    tables = []
    joins  = [{:synonym => :names}]

    conds += sql_id_or_name(:creator, 'names.user_id', 'users.login', 'users.name')
    conds += sql_id(:editor, 'names_versions.user_id')
    conds += sql_date(:created, 'names.created')
    conds += sql_date(:modified, 'names.modified')
    conds += sql_search(:author, 'names.author')
    conds += sql_search(:citation, 'names.citation')
    conds += sql_search(:classification, 'names.classification')
    conds += sql_enum(:rank, 'names.rank', Name.all_ranks)
    conds += sql_boolean(:deprecated, 'names.deprecated')
    conds += sql_boolean(:misspelling, '(names.correct_spelling_id NOT NULL)')
    conds += sql_boolean(:has_description, '(names.description_id NOT NULL)')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'names.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds  << 'users.id = names.user_id'
    end
    if uses_table?(conds, 'names_versions')
      tables << :names_versions
      conds  << 'names_versions.name_id = names.id'
    end

    return [conds, tables, joins, 1000]
  end

  def get_name_description
    conds  = []
    tables = []
    joins  = []

    # conds += sql_xxx(:author, xxx)
    # conds += sql_xxx(:editor, xxx)
    conds += sql_date(:created, 'name_descriptions.created')
    conds += sql_date(:modified, 'name_descriptions.modified')
    conds += sql_id_or_name(:name, 'name_descriptions.name_id', 'names.text_name', 'names.search_name')
    conds += sql_enum(:source_type, 'name_descriptions.source_type', Description.all_source_types)
    conds += sql_search(:source_name, 'name_descriptions.source_name')
    conds += sql_boolean(:public, 'name_descriptions.public')
    conds += sql_id(:license, 'name_descriptions.license_id')
    conds += sql_search(:search, NameDescription.all_note_fields.map {|x| "name_descriptions.#{x}"})
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'name_descriptions.id')

    if uses_table?(conds, 'names')
      tables << :names
      conds  << 'names.id = name_descriptions.name_id'
    end

    return [conds, tables, joins, 100]
  end

  def get_naming
    conds  = []
    tables = []
    joins  = [:user, :observation, :name, :votes]

    conds += sql_date(:created, 'namings.created')
    conds += sql_date(:modified, 'namings.modified')
    conds += sql_id(:observation, 'namings.observation_id')
    conds += sql_id_or_name(:user, 'namings.user_id', 'users.login', 'users.name')
    conds += sql_id_or_name(:name, 'namings.name_id', 'names.text_name', 'names.search_name')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'namings.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds  << 'users.id = namings.user_id'
    end
    if uses_table?(conds, 'names')
      tables << :names
      conds  << 'names.id = namings.name_id'
    end

    return [conds, tables, joins, 1000]
  end

  def get_notification
    conds  = []
    tables = []
    joins  = []

    raise error(303, "must login to process your notifications") if !user
    conds += build_sql(["notifications.user_id = ?", user.id])
    conds += sql_date(:created, 'notifications.created')
    conds += sql_date(:modified, 'notifications.modified')
    conds += sql_enum(:object_type, 'notifications.flavor', [:name])
    conds += sql_id(:object_id, 'notifications.obj_id')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'notifications.id')

    return [conds, tables, joins, 1000]
  end

  def get_observation
    conds  = []
    tables = []
    joins  = [
      :user,
      :location,
      {:name => {:synonym => :names}},
      {:namings => :name},
      {:images => [:user, :license]},
      {:comments => :user}
    ]

    conds += sql_date(:created, 'observations.created')
    conds += sql_date(:modified, 'observations.modified')
    conds += sql_date(:date, 'observations.when')
    conds += sql_id_or_name(:user, 'observations.user_id', 'users.login', 'users.name')
    conds += sql_id_or_name(:name, 'observations.name_id', 'names.text_name', 'names.search_name')
    conds += sql_id_or_name(:location, 'observations.location_id', 'observations.where', 'locations.name')
    conds += sql_search(:notes, 'observations.notes')
    conds += sql_boolean(:has_image, '(observations.thumb_image_id NOT NULL)')
    conds += sql_boolean(:has_specimen, 'observations.specimen')
    conds += sql_boolean(:is_collection_location, 'observations.is_collection_location')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'observations.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds  << 'users.id = observations.user_id'
    end
    if uses_table?(conds, 'names')
      tables << :names
      conds  << 'names.id = observations.name_id'
    end
    if uses_table?(conds, 'locations')
      tables << :locations
      conds  << 'locations.id = observations.location_id'
    end

    return [conds, tables, joins, 100]
  end

  def get_project
    conds  = []
    tables = []
    joins  = []

    conds += sql_date(:created, 'projects.created')
    conds += sql_date(:modified, 'projects.modified')
    conds += sql_search(:title, 'projects.title')
    conds += sql_search(:summary, 'projects.summary')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'projects.id')

    return [conds, tables, joins, 1000]
  end

  def get_species_list
    conds  = []
    tables = []
    joins  = []

    conds += sql_id_or_name(:user, 'species_lists.user_id', 'users.login', 'users.name')
    conds += sql_date(:created, 'species_lists.created')
    conds += sql_date(:modified, 'species_lists.modified')
    conds += sql_date(:date, 'species_lists.when')
    conds += sql_search(:title, 'species_lists.title')
    conds += sql_search(:notes, 'species_lists.notes')
    conds += sql_id(:observation, 'observations_species_lists.observation_id')
    conds += sql_id_or_name(:location, 'species_lists.location_id', 'species_lists.where', 'locations.name')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'species_lists.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds  << 'users.id = species_lists.user_id'
    end
    if uses_table?(conds, 'locations')
      tables << :locations
      conds  << 'locations.id = species_lists.location_id'
    end
    if uses_table?(conds, 'names')
      tables << :names
      tables << :observations
      tables << :observations_species_lists
      conds  << 'observations.name_id = names.id'
      conds  << 'observations_species_lists.observation_id = observations.id'
      conds  << 'observations_species_lists.species_list_id = species_lists.id'
    elsif uses_table?(conds, 'observations')
      tables << :observations
      tables << :observations_species_lists
      conds  << 'observations_species_lists.observation_id = observations.id'
      conds  << 'observations_species_lists.species_list_id = species_lists.id'
    elsif uses_table?(conds, 'observations_species_lists')
      tables << :observations_species_lists
      conds  << 'observations_species_lists.species_list_id = species_lists.id'
    end

    return [conds, tables, joins, 1000]
  end

  def get_user
    conds  = []
    tables = []
    joins  = [:location, :image]

    conds += sql_date(:created, 'users.created')
    conds += sql_date(:modified, 'users.modified')
    conds += sql_search(:name, 'users.login', 'users.name')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'users.id')

    return [conds, tables, joins, 1000]
  end

  def get_user_group
    conds  = []
    tables = []
    joins  = [:users]

    conds += sql_date(:created, 'user_groups.created')
    conds += sql_date(:modified, 'user_groups.modified')
    conds += sql_search(:name, 'user_groups.name')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'user_groups.id')

    return [conds, tables, joins, 1000]
  end

  def get_vote
    conds  = []
    tables = []
    joins  = []

    conds += sql_id_or_name(:user, 'votes.user_id', 'users.login', 'users.name')
    conds += sql_date(:created, 'votes.created')
    conds += sql_date(:modified, 'votes.modified')
    conds += sql_id(:observation, 'votes.observation_id')
    conds += sql_id(:naming, 'votes.naming_id')
    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'votes.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds  << 'users.id = votes.user_id'
    end

    return [conds, tables, joins, 1000]
  end

  ##############################################################################
  #
  #  :section: POST Methods
  #
  #  These are responsible for parsing all the parameters necessary to create a
  #  single new object.  If successful, they return the new object, otherwise
  #  they return nil.
  #
  #  Several "global" instance variables can be useful:
  #
  #  <tt>user</tt>::       User posting the new object.
  #  <tt>time</tt>::       Time request was _submitted_ (if not now).
  #  <tt>args[:http_request_body]</tt>::
  #                        This is where an image comes in from HTTP post.
  #
  #  These methods all rely heavily on a set of useful helpers that parse and
  #  validate the parameters.  Here are several:
  #
  #  parse_boolean::    Parse boolean.
  #  parse_integer::    Parse integer.
  #  parse_float::      Parse floating point.
  #  parse_string::     Parse string (with optional max length).
  #  parse_date::       Parse date.
  #  parse_object::     Parse object (by id or sync_id).
  #  parse_vote::       Parse confidence level.
  #  parse_rank::       Parse name rank ('Genus', 'Species', etc.).
  #
  #  These raise appropriate 102 errors in case of invalid values.  They return
  #  type-cast value if valid, or nil if the parameter wasn't specified.
  #
  ##############################################################################

  # ----------------------------
  #  Comments
  # ----------------------------

  def post_comment
    summary = parse_string(:summary, 100)
    content = parse_string(:content)

    object = nil
    object ||= parse_object(:location, Location)
    object ||= parse_object(:name, Name)
    object ||= parse_object(:observation, Observation)

    summary ||= '.'
    content ||= ''

    raise error(102, 'missing content') if !content
    raise error(102, 'missing object')  if !object

    comment = Comment.new(
      :created  => time,
      :modified => time,
      :user     => user,
      :summary  => summary,
      :comment  => content,
      :object   => object
    )
    save_new_object(comment)

    if object.respond_to?(:log)
      object.log(:log_comment_added, :summary => summary)
    end
    return comment
  end

  # ----------------------------
  #  Images
  # ----------------------------

  def post_image
    temp = nil

    url              = parse_string(:url)
    file             = parse_string(:file)
    date             = parse_date(:date)
    notes            = parse_string(:notes)
    copyright_holder = parse_string(:copyright_holder, 100)
    license          = parse_object(:license, License)
    observation      = parse_object(:observation, Observation)

    date             ||= observation.when if observation
    notes            ||= ''
    copyright_holder ||= user.legal_name
    license          ||= user.license

    raise error(102, 'missing date') if !date
    raise error(102, 'cannot use both url and file') if url && file
    raise error(102, 'only jason can use file') if file && user.login != 'jason'
    raise error(102, 'expected file to be "name.jpg"') if file && !file.match(/^[\w\.\-]+\.jpg$/)

    image = Image.new(
      :created          => time,
      :modified         => time,
      :user             => user,
      :when             => date,
      :notes            => notes,
      :copyright_holder => copyright_holder,
      :license          => license
    )

    if url
      image.image = temp = load_from_url(url)
    elsif file
      image.image = temp = "/home/jason/images/#{file}"
    else
      request = @args[:http_request_body]
      image.image = request.body
      image.upload_length = request.content_length
      image.upload_type   = request.content_type
      image.upload_md5sum = request.headers['Content-MD5']
    end

    save_new_object(image)
    raise error(202, image.formatted_errors) if !image.process_image

    if observation
      observation.add_image(image)
      observation.log_create_image(image)
    end
    return image

  ensure
    # Make sure the temp file is deleted.
    File.delete(temp) if temp
  end

  # ----------------------------
  #  Interests
  # ----------------------------

  def post_interest
    state = parse_boolean(:state)

    object = nil
    object ||= parse_object(:location, Location)
    object ||= parse_object(:name, Name)
    object ||= parse_object(:observation, Observation)

    raise error(102, 'missing state')  if state.nil?
    raise error(102, 'missing object') if !object

    interest = Interest.new(
      :modified => time,
      :user     => user,
      :state    => state,
      :object   => object
    )
    save_new_object(interest)
    return interest
  end

  # ----------------------------
  #  Licenses
  # ----------------------------

  def post_license
    must_be_safe

    display_name = parse_string(:display_name, 80)
    form_name    = parse_string(:form_name, 80)
    url          = parse_string(:url, 200)
    deprecated   = parse_boolean(:deprecated)

    raise error(102, 'missing display_name') if !display_name
    raise error(102, 'missing form_name')    if !form_name
    raise error(102, 'missing url')          if !url

    license = License.new(
      :modified     => time,
      :display_name => display_name,
      :form_name    => form_name,
      :url          => url,
      :deprecated   => deprecated
    )
    save_new_object(license)
    return license
  end

  # ----------------------------
  #  Locations
  # ----------------------------

  def post_location
    name  = parse_string(:name, 200)
    north = parse_float(:north)
    south = parse_float(:south)
    east  = parse_float(:east)
    west  = parse_float(:west)
    high  = parse_float(:high)
    low   = parse_float(:low)

    raise error(102, 'missing name')  if !name
    raise error(102, 'missing north') if !north
    raise error(102, 'missing south') if !south
    raise error(102, 'missing east')  if !east
    raise error(102, 'missing west')  if !west

    # Check if already exists.
    if Location.find_by_name(name)
      raise error(202, "location already exists")
    end

    location = Location.new(
      :created          => time,
      :modified         => time,
      :user             => user,
      :display_name     => name,
      :north            => north,
      :south            => south,
      :east             => east,
      :west             => west,
      :high             => high,
      :low              => low
    )
    save_new_object(location)
    return location
  end

  # ----------------------------
  #  Names
  # ----------------------------

  def post_name
    name_str         = parse_string(:name, 100)
    author           = parse_string(:author, 100)
    rank             = parse_rank(:rank)
    citation         = parse_string(:citation)
    deprecated       = parse_boolean(:deprecated)
    correct_spelling = parse_object(:correct_spelling, Name)
    classification   = parse_string(:classification)
    notes            = parse_string(:notes)

    raise error(102, 'missing rank') if !rank
    raise error(102, 'missing name') if !name_str

    # Make sure name doesn't already exist.
    match = nil
    if !author.blank?
      match = Name.find_by_text_name_and_author(name_str, author)
      name_str2 = "#{name_str} #{author}"
    else
      match = Name.find_by_text_name(name_str)
      name_str2 = name_str
    end
    raise error(202, "name already exists") if match

    # Make sure the name parses.
    names = Name.names_from_string(name_str2)
    name  = names.last
    raise error(202, "invalid name") if name.nil?

    # Fill in information.
    name.rank             = rank
    name.citation         = citation
    name.deprecated       = deprecated
    name.correct_spelling = correct_spelling
    name.classification   = classification
    name.notes            = notes
    name.change_text_name(name_str, author, rank)
    name.change_deprecated(true) if deprecated

    # Save it and any implictly-created parents (e.g. genus when creating
    # species for unrecognized genus).
    for name in names
      if name
        name.created  = time
        name.modified = time
        name.user     = user
        name.save
        name.add_editor(user)
      end
    end
    return name
  end

  # ----------------------------
  #  Descriptions
  # ----------------------------

  def post_location_description
    post_description(:location, Location, LocationDescription)
  end

  def post_name_description
    post_description(:name, Name, NameDescription)
  end

  def post_description(type, parent_model, model)
    parent        = parse_object(type, parent_model)
    source_type   = parse_enum(:source_type, Description.all_source_types)
    source_name   = parse_string(:source_name, 100)
    locale        = parse_string(:locale, 8)
    license       = parse_object(:license, License)
    public_read   = parse_boolean(:public_read)
    public_write  = parse_boolean(:public_write)
    admin_groups  = parse_objects(:admin_groups, UserGroup)
    writer_groups = parse_objects(:writer_groups, UserGroup)
    reader_groups = parse_objects(:reader_groups, UserGroup)
    notes = {}
    for f in model.all_note_fields
      notes[f] = parse_string(f)
    end

    public_read  = true if public_read.nil?
    public_write = true if public_write.nil?
    locale ||= DEFAULT_LOCALE

    raise error(102, "missing #{type}") if !parent

    # Give source-specific defaults.
    source_type ||= :public
    case source_type
    when :public
      admin_groups  = [UserGroup.reviewers]
      writer_groups = [UserGroup.all_users]
      reader_groups = [UserGroup.all_users]
    when :foreign
      must_be_safe
      admin_groups  = [UserGroup.reviewers]
      writer_groups = [UserGroup.reviewers]
      reader_groups = [UserGroup.all_users]
    when :project
      project = parse_object(:project, Project)
      raise error(102, "missing project") if !project
      source_name = project.title
      admin_groups  ||= [project.admin_group]
      writer_groups ||= public_write ? [UserGroup.all_users] :
                              [project.admin_group, UserGroup.one_user(user)]
      reader_groups ||= public_read ? [UserGroup.all_users] :
                                      [project.user_group]
    when :source
      raise error(102, "missing source_name") if !source_name
      admin_groups  ||= [UserGroup.one_user(user)]
      reader_groups ||= public_write ? [UserGroup.all_users] :
                                      [UserGroup.one_user(user)]
      reader_groups ||= public_read ? [UserGroup.all_users] :
                                      [UserGroup.one_user(user)]
    when :user
      admin_groups  ||= [UserGroup.one_user(user)]
      reader_groups ||= public_write ? [UserGroup.all_users] :
                                      [UserGroup.one_user(user)]
      reader_groups ||= public_read ? [UserGroup.all_users] :
                                      [UserGroup.one_user(user)]
    end
    public = reader_groups.include?(UserGroup.all_users)

    desc = model.new(
      :created     => time,
      :modified    => time,
      :user        => user,
      :parent      => parent,
      :source_type => source_type,
      :source_name => source_name,
      :public      => public,
      :license     => license,
      :locale      => locale,
      :all_notes   => notes
    )
    save_new_object(desc)

    if public && !parent.description_id
      parent.description = desc
      parent.save_without_our_callbacks
    end

    return desc
  end

  # ----------------------------
  #  Namings
  # ----------------------------

  def post_naming
    name        = parse_object(:name, Name)
    observation = parse_object(:observation, Observation)
    vote        = parse_vote(:vote)
    reasons = {}
    for num in Naming::Reason.all_reasons
      reasons[num] = parse_string("reason_#{num}")
    end

    raise error(102, 'missing name')        if !name
    raise error(102, 'missing observation') if !observation
    raise error(102, 'missing vote')        if !vote

    naming = Naming.new(
      :created     => time,
      :modified    => time,
      :user        => user,
      :observation => observation,
      :name        => name,
      :set_reasons => reasons
    )
    save_new_object(naming)

    # Attach vote.
    observation.change_vote(naming, vote, user)

    return naming
  end

  # ----------------------------
  #  Notifications
  # ----------------------------

  def post_notification
    name          = parse_object(:name, Name)
    note_template = parse_string(:note_template)

    raise error(102, 'missing name') if !name

    notification = Notification.new(
      :modified => time,
      :user     => user,
      :flavor   => :name,
      :obj_id   => name.id,
      :note_template => note_template
    )
    save_new_object(notification)
    return notification
  end

  # ----------------------------
  #  Observations
  # ----------------------------

  def post_observation
    date                   = parse_date(:date)
    location, where        = parse_where(:location)
    specimen               = parse_boolean(:specimen)
    is_collection_location = parse_boolean(:is_collection_location)
    notes                  = parse_string(:notes)
    thumbnail              = parse_object(:thumbnail, Image)
    images                 = parse_objects(:images, Image)

    date                   ||= time
    specimen               ||= false if specimen.nil?
    is_collection_location ||= true  if is_collection_location.nil?
    notes                  ||= ''
    images                 ||= []
    images.unshift(thumbnail) if !images.include?(thumbnail)

    raise error(102, 'missing location') if !location and !where

    obs = Observation.new(
      :created                => time,
      :modified               => time,
      :user                   => user,
      :when                   => date,
      :where                  => where,
      :location               => location,
      :specimen               => specimen,
      :is_collection_location => is_collection_location,
      :notes                  => notes,
      :thumb_image            => thumbnail,
      :images                 => images
    )
    save_new_object(obs)
    obs.log(:log_observation_created)
    return obs
  end

  # ----------------------------
  #  Projects
  # ----------------------------

  def post_project
    must_be_safe

    title       = parse_string(:title, 100)
    summary     = parse_string(:summary)
    admin_group = parse_object(:admin_group, UserGroup)
    user_group  = parse_object(:user_group, UserGroup)

    raise error(102, 'missing title')       if !title
    raise error(102, 'missing admin group') if !admin_group
    raise error(102, 'missing user group')  if !user_group

    project = Project.new(
      :created     => time,
      :modified    => time,
      :user        => user,
      :title       => title,
      :summary     => summary,
      :admin_group => admin_group,
      :user_group  => user_group
    )
    save_new_object(project)
    return project
  end

  # ----------------------------
  #  Species Lists
  # ----------------------------

  def post_species_list
    date            = parse_date(:date)
    location, where = parse_where(:location)
    title           = parse_string(:title, 100)
    notes           = parse_string(:notes)
    observations    = parse_objects(:observations, Observation)

    observations ||= []
    if sample = observations.first
      date     ||= sample.when
      where    ||= sample.where
      location ||= sample.location
    end

    raise error(102, 'missing date')     if !date
    raise error(102, 'missing location') if !location and !where
    raise error(102, 'missing title')    if !title

    spl = SpeciesList.new(
      :created      => time,
      :modified     => time,
      :user         => user,
      :when         => date,
      :where        => where,
      :location     => location,
      :title        => title,
      :notes        => notes,
      :observations => observations
    )
    save_new_object(spl)
    return spl
  end

  # ----------------------------
  #  Users
  # ----------------------------

  def post_user
    must_be_safe

    login           = parse_string(:set_login, 80)
    name            = parse_string(:set_name,  80)
    email           = parse_string(:set_email, 80)
    notes           = parse_string(:set_notes)
    image           = parse_object(:set_image, Image)
    location        = parse_object(:set_location, Location)
    mailing_address = parse_string(:set_mailing_address)
    license         = parse_object(:set_license, License)
    locale          = parse_string(:set_locale, 5)

    # Let's try never to fail on this, since the user record being created is
    # pretty minimal and emasculated anyway (no password for example).
    raise error(102, 'missing login') if !login

    # Make sure login is unique.
    while User.find_by_login(login)
      if login.match(/\d$/)
        login.next!
      else
        login += '2'
      end
    end

    user = User.new(
      :created         => time,
      :modified        => time,
      :login           => login,
      :password        => '',
      :name            => name,
      :email           => email,
      :notes           => notes,
      :image           => image,
      :location        => location,
      :mailing_address => mailing_address,
      :license         => license,
      :locale          => locale,
      :admin           => false,
      :created_here    => false
    )
    save_new_object(group)
    return group
  end

  # ----------------------------
  #  User Groups
  # ----------------------------

  def post_user_group
    must_be_safe

    name  = parse_string(:name, 255)
    users = parse_objects(:users, User)

    users ||= []

    raise error(102, 'missing name') if !name

    group = UserGroup.new(
      :created  => time,
      :modified => time,
      :name     => name,
      :users    => user,
      :meta     => false
    )
    save_new_object(group)
    return group
  end

  # ----------------------------
  #  Votes
  # ----------------------------

  def post_vote
    naming = parse_object(:naming, Naming)
    value  = parse_vote(:value)

    raise error(102, 'missing naming') if !naming
    raise error(102, 'missing vote')   if !vote

    naming.observation.change_vote(naming, vote, user)
    return Vote.find_by_user_id_and_naming_id(user.id, naming.id)
  end

  ##############################################################################
  #
  #  :section: PUT Methods
  #
  #  These are responsible for parsing all the "set" parameters and returning a
  #  Proc that will be called on each object to be modified.
  #
  #  These methods all rely heavily on a set of useful helpers that parse and
  #  validate the "set_blah" parameters.  Here are several:
  #
  #  parse_boolean::    Parse boolean.
  #  parse_integer::    Parse integer.
  #  parse_float::      Parse floating point.
  #  parse_string::     Parse string (with optional max length).
  #  parse_date::       Parse date.
  #  parse_object::     Parse object (by id or sync_id).
  #  parse_vote::       Parse confidence level.
  #  parse_rank::       Parse name rank ('Genus', 'Species', etc.).
  #
  #  These raise appropriate 102 errors in case of invalid values.  They return
  #  type-cast value if valid, or nil if the parameter wasn't specified.
  #
  ##############################################################################

  def put_comment
    sets = {}
    sets[:summary]   = x if x = parse_string(:set_summary, 100)
    sets[:comment]   = x if x = parse_string(:set_comment)
    return standard_setter(sets)
  end

  def put_image
    sets = {}
    sets[:when]             = x if x = parse_date(:set_date)
    sets[:notes]            = x if x = parse_string(:set_notes)
    sets[:copyright_holder] = x if x = parse_string(:set_copyright_holder, 100)
    sets[:license]          = x if x = parse_object(:set_license, License, false)
    return standard_setter(sets)
  end

  def put_interest
    sets = {}
    sets[:state] = x if x = parse_boolean(:set_state)
    return standard_setter(sets)
  end

  def post_license
    must_be_safe
    sets = {}
    sets[:display_name] = parse_string(:set_display_name, 80)
    sets[:form_name]    = parse_string(:set_form_name, 80)
    sets[:url]          = parse_string(:set_url, 200)
    sets[:deprecated]   = parse_boolean(:set_deprecated)
    return standard_setter(sets)
  end

  def put_location
    sets = {}
    sets[:display_name] = x if x = parse_string(:set_name, 200)
    sets[:north]        = x if x = parse_float(:set_north)
    sets[:south]        = x if x = parse_float(:set_south)
    sets[:east]         = x if x = parse_float(:set_east)
    sets[:west]         = x if x = parse_float(:set_west)
    sets[:high]         = x if x = parse_float(:set_high)
    sets[:low]          = x if x = parse_float(:set_low)
    any_changes?(sets)
    return lambda do |obj|
      must_authenticate
      obj.attributes = sets
      # Check for merge.
      merge = Location.find_by_name(obj.name)
      if merge == obj
        save_changes(obj)
      else
        obj, merge = merge, obj if !obj.mergable? and merge.mergable?
        if obj.mergable || safe
          merge.merge(obj)
          merge.save if merge.changed?
          obj = merge
        else
          content = :email_location_merge.t(:user => user.login,
                  :this => obj.display_name, :that => merge.display_name)
          AccountMailer.deliver_webmaster_question(user.email, content)
          raise error(203, "dangerous merge requires admin")
        end
      end
      return obj
    end
  end

  def put_location_description
    sets = {}
    sets[:source_type]   = x if x = parse_string(:set_source_type, Description.all_source_types)
    sets[:source_name]   = x if x = parse_string(:set_source_name, 100)
    sets[:locale]        = x if x = parse_string(:set_locale, 8)
    sets[:license]       = x if x = parse_object(:set_license, License, false)
    sets[:admin_groups]  = x if x = parse_objects(:set_admins, UserGroup)
    sets[:writer_groups] = x if x = parse_objects(:set_writers, UserGroup)
    sets[:reader_groups] = x if x = parse_objects(:set_readers, UserGroup)
    for f in LocationDescription.all_note_fields
      sets[f] = x if x = parse_string(:"set_#{f}")
    end
    any_changes?(sets)
    return lambda do |obj|
      must_be_writer(obj)
      sets2 = enforce_description_permissions(obj, sets)
      update_attributes(obj, sets2)
      return obj
    end
  end

  def put_name
    sets = {}
    sets[:rank]             = x if x = parse_enum(:set_rank, Name.all_ranks)
    sets[:text_name]        = x if x = parse_string(:set_name, 100)
    sets[:author]           = x if x = parse_string(:set_author, 100)
    sets[:citation]         = x if x = parse_string(:set_citation)
    sets[:deprecated]       = x if x = parse_boolean(:set_deprecated)
    sets[:synonym_id]       = x if x = parse_integer(:set_synonym)
    sets[:correct_spelling] = x if x = parse_boolean(:set_correct_spelling)
    sets[:notes]            = x if x = parse_string(:set_notes)
    any_changes?(sets)
    if sets[:synonym_id] == 0
      sets.delete(:synyonym_id)
      clear_synonym = true
    end
    if !safe
      delete sets[:text_name]
      delete sets[:author]
    end
    return lambda do |obj|
      must_authenticate
      # Delete synonym if no longer useful.
      if clear_synonym and
         (obj.synonym.names.length <= 2)
        obj.synonym.destroy
      end
      obj.attributes = sets
      # Refresh names if name, author, or deprecated changed.
      if obj.text_name_changed? or
         obj.author_changed? or
         obj.deprecated_changed?
        obj.change_text_name(obj.text_name, obj.author, obj.rank)
        obj.deprecated(true) if obj.deprecated
      end
      # Check for merge.
      matches = if obj.author.blank?
        Name.find_all_by_text_name(obj.text_name)
      else
        Name.find_all_by_text_name_and_author(obj.text_name, obj.author)
      end
      if merge = (matches - [obj]).first
        obj, merge = merge, obj if !obj.mergable? and merge.mergable?
        if obj.mergable || safe
          merge.merge(obj)
          merge.save if merge.changed?
          obj = merge
        else
          content = :email_name_merge.t(:user => user.login,
                    :this => obj.display_name, :that => merge.display_name)
          AccountMailer.deliver_webmaster_question(user.email, content)
          raise error(203, "dangerous merge requires admin")
        end
      else
        save_changes(obj)
      end
      return obj
    end
  end

  def put_name_description
    sets = {}
    sets[:source_type]   = x if x = parse_string(:set_source_type, Description.all_source_types)
    sets[:source_name]   = x if x = parse_string(:set_source_name, 100)
    sets[:locale]        = x if x = parse_string(:set_locale, 8)
    sets[:license]       = x if x = parse_object(:set_license, License, false)
    sets[:admin_groups]  = x if x = parse_objects(:set_admins, UserGroup)
    sets[:writer_groups] = x if x = parse_objects(:set_writers, UserGroup)
    sets[:reader_groups] = x if x = parse_objects(:set_readers, UserGroup)
    for f in NameDescription.all_note_fields
      sets[f] = x if x = parse_string(:"set_#{f}")
    end
    any_changes?(sets)
    return lambda do |obj|
      must_be_writer(obj)
      sets2 = enforce_description_permissions(obj, sets)
      update_attributes(obj, sets2)
      return obj
    end
  end

  def put_naming
    sets = {}
    sets[:name] = x if x = parse_object(:set_name, Name)
    for num in Naming::Reason.all_reasons
      if x = parse_string("set_reason_#{num}".to_sym)
        sets["reason_#{num}".to_sym] = x
      end
    end
    any_changes?(sets)
    return lambda do |obj|
      must_be_owner(obj)
      # Change name.
      if (new_name = sets[:name]) && (obj.name != new_name)
        if obj.observation.name_been_proposed?(new_name)
          @errors << error(203, "name #{new_name.id} has already been proposed (naming ##{obj.id})")
        elsif !obj.editable?
          @errors << error(203, "not allowed to change naming ##{obj.id} since at least one other user has given it a positive vote")
        else
          if update_naming_object(obj, new_name, true)
            # Invalidate votes if name changed.
            for vote in obj.votes
              vote.destroy if vote.user_id != @user.id
            end
            obj.observation.calc_consensus(@user)
          end
        end
      end
      # Update reasons.
      for reason in obj.get_reasons
        if val = sets[:"reason_#{reason.num}"]
          reason.notes = val
        else
          reason.delete
        end
      end
      save_changes(obj)
      return obj
    end
  end

  def put_notification
    sets = {}
    sets[:flavor]        = x if x = parse_enum(:set_flavor, [:name])
    sets[:object]        = x if x = parse_object(:set_object, Name)
    sets[:note_template] = x if x = parse_string(:set_note_template)
    return standard_setter(sets)
  end

  def put_observation
    sets = {}
    sets[:location], sets[:where] = *x if x = parse_where(:set_location)
    sets[:when]                   = x if x = parse_date(:set_date)
    sets[:notes]                  = x if x = parse_string(:set_notes)
    sets[:thumb_image]            = x if x = parse_object(:set_thumbnail, Image)
    sets[:specimen]               = x if x = parse_boolean(:set_specimen)
    sets[:is_collection_location] = x if x = parse_boolean(:set_is_collection_location)
    return standard_setter(sets)
  end

  def put_project
    sets = {}
    sets[:title]       = x if x = parse_string(:set_title, 100)
    sets[:summary]     = x if x = parse_string(:set_summary)
    sets[:admin_group] = x if x = parse_object(:set_admin_group, UserGroup)
    sets[:user_group]  = x if x = parse_object(:set_user_group, UserGroup)
    return standard_setter(sets)
  end

  def put_species_list
    sets = {}
    sets[:location], sets[:where] = *x if x = parse_where(:set_location)
    sets[:when]  = x if x = parse_date(:set_date)
    sets[:title] = x if x = parse_string(:set_title, 100)
    sets[:notes] = x if x = parse_string(:set_notes)
    return standard_setter(sets)
  end

  def put_user
    sets = {}
    sets[:login]           = x if x = parse_string(:set_login, 80)
    sets[:name]            = x if x = parse_string(:set_name,  80)
    sets[:email]           = x if x = parse_string(:set_email, 80)
    sets[:verify]          = x if x = parse_boolean(:set_verify)
    sets[:notes]           = x if x = parse_string(:set_notes)
    sets[:image]           = x if x = parse_object(:set_image, Image)
    sets[:location]        = x if x = parse_object(:set_location, Location)
    sets[:mailing_address] = x if x = parse_string(:set_mailing_address)
    sets[:license]         = x if x = parse_object(:set_license, License)
    sets[:locale]          = x if x = parse_string(:set_locale, 5)
    sets[:votes_anonymous] = x if x = parse_enum(:set_votes_anonymous, [:yes, :no, :old])
    sets[:email_html]      = x if x = parse_boolean(:set_email_html)
    return standard_setter(sets)
  end

  def put_user_group
    sets = {}
    name = parse_string(:set_name, 255)
    adds = parse_objects(:add_user, User)
    dels = parse_objects(:del_user, User)
    any_changes?(false) unless name || adds || dels
    return lambda do |obj|
      must_be_safe
      # Don't allow meta-groups to change name.
      if !obj.meta and (obj.name != name)
        obj.name = name
        obj.save
      end
      # Add or remove users.
      obj.users.push(*adds)   if adds
      obj.users.delete(*dels) if dels
      return obj
    end
  end

  def put_vote
    val = parse_vote(:set_value)
    any_changes?(false) if !val
    return lambda do |obj|
      must_be_owner(obj)
      if (obj.value != val) and
         !obj.observation.change_vote(obj.naming, val, user)
        raise error(203, obj.formatted_errors)
      end
      return obj
    end
  end

  ##############################################################################
  #
  #  :section: DELETE Methods
  #
  #  These are responsible for deleting a single object each.  Most will simply
  #  call destroy and be done with it, others require more work:
  #
  #    # Comments are simple, just destroy.
  #    def delete_comment(comment)
  #      return comment.destroy
  #    end
  #
  #    # Namings, on the other hand, are not always deletable.
  #    def delete_naming(naming)
  #      if !naming.deletable?
  #        @errors << error(204, "not allowed to delete naming")
  #        return false
  #      else
  #        return naming.destroy
  #      end
  #    end
  #
  ##############################################################################

  def delete_comment(obj)
    must_be_owner(obj)
    destroy_object(obj)
  end

  def delete_image(obj)
    must_be_owner(obj)
    destroy_object(obj)
  end

  def delete_interest(obj)
    must_be_owner(obj)
    destroy_object(obj)
  end

  # Locations can only be "deleted" by merging with other locations.
  # def delete_location(obj)
  #   must_be_safe
  #   destroy_object(obj)
  # end

  def delete_location_description(obj)
    must_be_admin(obj)
  end

  # Locations can only be "deleted" by merging with other locations.
  # def delete_name(obj)
  #   must_be_safe
  #   destroy_object(obj)
  # end

  def delete_name_description(obj)
    must_be_admin(obj)
  end

  def delete_naming(obj)
    if !naming.deletable?
      raise error(204, "this is someone's favorite name for this observation")
    end
    must_be_owner(obj)
    destroy_object(obj)
  end

  def delete_notification(obj)
    must_be_owner(obj)
    destroy_object(obj)
  end

  def delete_observation(obj)
    must_be_owner(obj)
    destroy_object(obj)
  end

  def delete_project(obj)
    must_be_owner(obj)
    destroy_object(obj)
  end

  def delete_species_list(obj)
    must_be_owner(obj)
    destroy_object(obj)
  end

  def delete_user(obj)
    must_be_safe
    destroy_object(obj)
  end

  def delete_user_group(obj)
    must_be_safe
    destroy_object(obj)
  end

  def delete_vote(obj)
    must_be_owner(obj)
    if obj.naming.user == user
      raise error(204, "cannot delete your vote on your own naming")
    end
    obj.observation.change_vote(obj.naming, Vote.delete_vote, user)
  end

  ################################################################################
  #
  #  :section: POST/PUT/DELETE Helpers
  #
  ################################################################################

  def standard_setter(obj, sets)
    any_changes?(sets)
    lambda do |obj|
      must_be_owner(obj)
      update_attributes(obj, sets)
      return obj
    end
  end

  def enforce_description_permissions(obj, sets)
    sets2 = sets.dup
    admin  = obj.is_admin?(user)
    author = obj.is_author?(user)
    sets2.delete(:source_type)   unless safe
    sets2.delete(:source_name)   unless safe or ((admin || author) and
      (obj.source_type != :project && obj.source_type != :project))
    sets2.delete(:license)       unless safe or admin or author
    sets2.delete(:admin_groups)  unless safe or admin
    sets2.delete(:writer_groups) unless safe or admin
    sets2.delete(:reader_groups) unless safe or admin
    return sets2
  end

  def any_changes?(hash)
    raise error(102, "you didn't specify any changes") if !hash || hash.empty?
  end

  def must_be_safe
    raise error(302, "must be admin") if !safe
  end

  def must_authenticate
    raise error(302, "must authenticate") if !user
  end

  def must_be_owner(obj)
    raise error(302, "must be owner") if obj.user != user
  end

  def save_new_object(obj)
    raise error(202, obj.formatted_errors) if !obj.save
  end

  def update_attributes(obj, vals)
    raise error(203, obj.formatted_errors) if !obj.update_attributes(vals)
  end

  def save_changes(obj)
    raise error(203, obj.formatted_errors) if !obj.save
  end

  def destroy_object(obj)
    raise error(204, obj.formatted_errors) if !obj.destroy
  end

  ##############################################################################
  #
  #  :section: Parsers
  #
  ##############################################################################

private

  # Pull argument out of request if given.
  def parse_arg(name) # :doc:
    name = name.to_sym
    @used ||= {}
    result = nil
    if !@args[name].blank?
      @used[name] = true
      result = @args[name].to_s
    end
    # Save this for error checking later (see make_sure_found_all_objects).
    @ids_arg = result if name == :id
    return result
  end

  # Get page number from arguments.
  def parse_page() # :doc:
    result = nil
    if x = parse_arg(:page)
      result = x.to_i
      raise error(102, "invalid page: '#{x}'") if result < 1
    else
      result = 1
    end
    return result
  end

  # Get page length from arguments.
  def parse_page_len(max) # :doc:
    result = nil
    if x = parse_arg(:page_len)
      result = x.to_i
      raise error(102, "invalid page_len: '#{x}'") if result < 1
      raise error(102, "page_len too large: '#{x}' (max is #{max})") if result > max
    else
      result = max/10
    end
    return result
  end

  # Parse and validate a boolean.
  def parse_boolean(arg) # :doc:
    result = nil
    if x = parse_arg(arg)
      if x == '0' || x.downcase == 'false'
        result = false
      elsif x == '1' || x.downcase == 'true'
        result = true
      else
        raise error(102, "#{arg} should be 'true'/'false' or '1'/'0'")
      end
    end
    return result
  end

  # Parse and validate an integer.
  def parse_integer(arg) # :doc:
    result = nil
    if x = parse_arg(arg)
      if x.match(/^-?\d+$/)
        result = x.to_i
      else
        raise error(102, "#{arg} must be an integer")
      end
    end
    return result
  end

  # Parse and validate an integer.
  def parse_float(arg) # :doc:
    result = nil
    if x = parse_arg(arg)
      if x.match(/^-?(\d*\.\d+|\d+)$/)
        result = x.to_f
      else
        raise error(102, "#{arg} must be a floating-point")
      end
    end
    return result
  end

  # Parse and validate a vote (integer between 0 and 100).
  def parse_vote(arg) # :doc:
    result = nil
    if x = parse_arg(arg)
      if x.match(/^\d+$/) && x.to_i <= 100
        result = x.to_f / 100 * (Vote.maximum - Vote.minimum) + Vote.minimum
      else
        raise error(102, "#{arg} must be an integer between 0 and 100")
      end
    end
    return result
  end

  # Parse and validate a string.
  def parse_string(arg, length=nil) # :doc:
    result = nil
    if x = parse_arg(arg)
      if !length || x.length <= length
        result = x
      else
        raise error(102, "#{arg} must be #{length} characters or less")
      end
    end
    return result
  end

  # Parse and validate a date.
  def parse_date(arg) # :doc:
    result = nil
    if x = parse_arg(arg)
      if x.match(/^\d\d\d\d-?\d\d-?\d\d$/)
        result = Date.parse(x)
      else
        raise error(102, "#{arg} must be 'YYYY-MM-DD'")
      end
    end
    return result
  end

  # Parse and validate an object id.
  def parse_object(arg, model, strict=true) # :doc:
    result = nil
    if x = parse_arg(arg)
      if x.match(/^\d+$/)
        begin
          result = model.find(x.to_i)
        rescue
          raise error(102, "#{arg}=#{x} was not found") if strict
        end
      else
        raise error(102, "#{arg} must be integer id")
      end
    end
    return result
  end

  # Parse and validate an object id, returning id instead of object.  (Note,
  # it still does a 'find' to verify it exists.)
  def parse_object_id(arg, model, strict=true) # :doc:
    result = nil
    if x = parse_arg(arg)
      if x.match(/^\d+$/)
        begin
          result = model.find(x.to_i).id
        rescue
          raise error(102, "#{arg}=#{x} was not found") if strict
        end
      else
        raise error(102, "#{arg} must be integer id")
      end
    end
    return result
  end

  # Parse and validate a list of object ids.
  def parse_objects(arg, model) # :doc:
    result = nil
    if x = parse_arg(arg)
      result = []
      for y in x.split(',')
        if y.match(/^\d+$/)
          begin
            result << model.find(y.to_i)
          rescue
            raise error(102, "#{arg}=#{y} was not found")
          end
        else
          raise error(102, "#{arg} must be comma-separated list of integer ids")
        end
      end
    end
    return result
  end

  # Parse and validate an enumerated string.  This is case insensitive: it
  # removes case from the array of accepted values, matches the given value,
  # then returns the corresponding value given in the original set.
  def parse_enum(arg, accept) # :doc:
    result = nil
    map = {}
    for x in accept
      map[x.to_s.downcase] = x
    end
    if x = parse_arg(arg)
      if map.has_key?(x.downcase)
        result = map[x]
      else
        raise error(102, "#{arg} must be one of: (#{accept.map(&:to_s).join(', ')})")
      end
    end
    return result
  end

  # Parse and validate a rank.
  def parse_rank(arg) # :doc:
    parse_enum(arg, Name.all_ranks)
  end

  # Parse and validate the ambiguous Location id / 'where' String argument.
  # Returns nil if not given, or pair of values if given: Location instance,
  # 'where' String.
  def parse_where(arg)
    result = nil
    if x = parse_string(arg, 100)
      if (loc = Location.safe_find(x)) or
         (loc = Location.find_by_sync_id(x)) or
         (loc = Location.find_by_name(x))
        result = [loc, nil]
      else
        result = [nil, x]
      end
    end
    return result
  end

  ##############################################################################
  #
  #  :section: SQL Builders
  #
  ##############################################################################

private

  # Parse an id argument and build an SQL condition to process it.
  # Valid syntaxes:
  #   n
  #   m-n
  #   a,b,c-d,...
  def sql_id(arg, column) # :doc:
    result = []
    if x = parse_arg(arg)

      # Parse string into comma-delimited numbers and "m-n" ranges.
      singles = []
      ranges  = []
      for y in x.split(',')
        if y.match(/^\d+$/)
          a = y.to_i
          if a < 1 || a > 1e9
            raise error(102, "#{arg} out of range: '#{a}'")
          else
            singles << a
          end
        elsif y.match(/^(\d+)-(\d+)$/)
          a, b = $1.to_i, $2.to_i
          a, b = b, a if a > b
          if a < 1 || a > 1e9
            raise error(102, "#{arg} out of range: '#{a}'")
          elsif b < 1 || b > 1e9
            raise error(102, "#{arg} out of range: '#{b}'")
          elsif b - a > 1e6
            raise error(102, "#{arg} range too large: '#{a}-#{b}' (max is 1000000)")
          elsif b - a > 10
            ranges << (a..b)
          else
            singles += (a..b).to_a
          end
        else
          raise error(102, "invalid #{arg}: '#{y}'")
        end
      end

      # Combine the "blah IN (set)" and "blah BETWEEN a AND b" clauses.
      ors = []
      ors << build_sql(["#{column} IN (?)", singles]) if !singles.empty?
      for range in ranges
        ors << build_sql(["#{column} BETWEEN ? AND ?", range.begin, range.end])
      end
      result << '(' + ors.join(' OR ') + ')'

    end
    return result
  end

  # Parse an id/name argument and build an SQL condition to process it.
  # Valid syntaxes:
  #   a,b,c-d,...
  #      OR
  #   name1,name2,...
  def sql_id_or_name(arg, id_column, *name_columns) # :doc:
    result = []
    if x = parse_arg(arg)
      if x.match(/^[\d\-\,]*$/)
        result += sql_id(arg, id_column)
      else
        ors = []
        for y in x.split(',')
          for col in name_columns
            ors << build_sql(["#{col} = ?", y])
          end
        end
        result << '(' + ors.join(' OR ') + ')'
      end
    end
    return result
  end

  # Parse date argument and build an SQL condition to process it.
  # Valid syntaxes:
  #   YYYYMMDD
  #   YYYY-MM-DD
  def sql_date(arg, column) # :doc:
    result = []
    if x = parse_arg(arg)
      if x.match(/^\d\d\d\d-?\d\d-?\d\d$/)
        y = Date.parse(x)
        result << build_sql(["#{column} = ?", y])
      else
        raise error(102, "invalid #{arg}: '#{x}' (expect 'YYYY-MM-DD')")
      end
    end
    return result
  end

  # Parse date/time argument and build an SQL condition to process it.
  # Valid syntaxes:
  #   YYYYMMDDHHMMDD
  #   YYYY-MM-DD:HH:MM:SS
  #   YYYY-MM-DD HH:MM:SS
  #   YYYY-MM-DD-HH-MM-SS
  def sql_time(arg, column) # :doc:
    result = []
    if x = parse_arg(arg)
      if x.match(/^\d\d\d\d-?\d\d-?\d\d[-: ]?\d\d[-:]?\d\d[-:]?\d\d?$/)
        y = Time.parse(x)
        result << build_sql(["#{column} = ?", y])
      else
        raise error(102, "invalid #{arg}: '#{x}' (expect 'YYYY-MM-DD HH:MM:SS')")
      end
    end
    return result
  end

  # Parse text-search argument and build an SQL condition to process it.
  # Valid syntaxes:
  #   string
  def sql_search(arg, *columns) # :doc:
    result = []
    if x = parse_arg(arg)
      for col in columns
        result << build_sql(["#{col} LIKE ?", "%#{x}%"])
      end
    end
    return result
  end

  # Parse an enumerated argument and build an SQL condition to process it.
  # Valid syntaxes:
  #   val
  #   val1-val2
  #   val1,val2,...
  def sql_enum(arg, column, allowed) # :doc:
    result = []
    if x = parse_arg(arg)
      for y in x.split(',')
        if y.match(/-/)
          a, b = $`, $'
          if !(ai = allowed.index(a.to_sym))
            raise error(102, "invalid #{arg}: '#{a}' " +
                             "(expect '#{allowed.map(&:to_s).join("', '")}'")
          elsif !(bi = allowed.index(b.to_sym))
            raise error(102, "invalid #{arg}: '#{b}' " +
                             "(expect '#{allowed.map(&:to_s).join("', '")}'")
          end
          ai, bi = bi, ai if ai > bi
          if ai == bi
            result << build_sql(["#{column} = ?", a])
          else
            result << build_sql(["#{column} IN (?)", allowed[ai..bi]])
          end
        else
          if !allowed.include?(y)
            raise error(102, "invalid #{arg}: '#{y}' " +
                             "(expect '#{allowed.map(&:to_s).join("', '")}'")
          end
          result << build_sql(["#{column} = ?", y])
        end
      end
    end
    return result
  end

  # Parse a boolean argument and build an SQL condition that expresses it.
  # Note, +column+ can be any arbitrary SQL expression that evaluates to TRUE
  # or FALSE.  (Remember to include parens if required!)  Valid syntaxes:
  #   0, false, no
  #   1, true, yes
  def sql_boolean(arg, column) # :doc:
    result = []
    if x = parse_arg(arg)
      case x.downcase
      when '0', 'false', 'no'
        result << "#{column} IS FALSE"
      when '1', 'true', 'yes'
        result << "#{column} IS TRUE"
      else
        raise error(102, "invalid #{arg}: '#{x}' (expect '0', '1', 'false', " +
                         "'true', 'no', 'yes')
      end
    end
    return result
  end

  # Check if list of conditions uses a given table.
  def uses_table?(conds, table) # :doc:
    result = false
    for cond in conds
      if cond.include?("#{table}.")
        result = true
        break
      end
    end
    return result
  end

  # Short-hand method of calling the handy (but protected) sanitize_sql_array
  # method in ActiveRecord.
  def build_sql(*args) # :doc:
    ActiveRecord::Base.sanitize_sql_array_public(*args)
  end

  ##############################################################################
  #
  #  :section: Other Stuff
  #
  ##############################################################################

public

  # Create an MoApiException.
  def error(code, msg, fatal=false)
    MoApiException.new(
      :code  => code,
      :msg   => msg,
      :fatal => fatal
    )
  end

  # Make sure the given exception is an MoApiException.  If not, wrap it in an
  # MoApiException so that all errors are of the same type.
  def convert_error(e, code, msg, *args)
    if !e.is_a?(MoApiException)
      s = e.to_s
      s += "\n" + e.backtrace.join("\n") if !s.match(/\n.*\n.*\n/)
      s = "#{msg}: #{s}" if msg
      e = error(code, s, *args)
    end
    return e
  end

private

  # Check user's authentication.
  def authenticate(required=true) # :doc:
    result = nil
    begin
      auth_id   = parse_integer(:auth_id)
      auth_code = parse_string(:auth_code)
      if !(user = User.safe_find(auth_id))
        raise error(301, "invalid auth_id: '#{auth_id}'")
      elsif user.auth_code != auth_code
        raise error(301, "invalid auth_code: '#{auth_code}'")
      else
        result = user
      end
    rescue => e
      raise e if required
    end
    return result
  end

  # Raise errors for all unused arguments.
  def error_if_any_other_args() # :doc:
    (@args.keys - @used.keys).map(&:to_s).sort.each do |arg|
      @errors << error(102, "unrecognized argument: '#{arg}' (ignored)")
    end
  end

  # Check that objects were found for all the given ids.  (It uses the
  # "globals" @ids_arg and @something_besides_ids: the former is a list of
  # all the requested ids; the latter tells us if the search was futher refined
  # from the list of ids.  It expects every id listed individually to exist,
  # and at least one id to exist inside each range.  But only if there are no
  # restrictions besides ids.)
  def make_sure_found_all_objects(ids, type) # :doc:
    if @ids_arg && !@something_besides_ids
      for x in @ids_arg.split(',')
        if x.match(/^\d+$/)
          if !ids.include?(x.to_s) && !ids.include?(x.to_i)
            errors << error(201, "#{type} ##{x} not found")
          end
        elsif x.match(/^(\d+)-(\d+)$/)
          a, b = $1.to_i, $2.to_i
          a, b = b, a if a > b
          if !ids.any? {|x| x.to_i >= a || x.to_i <= b}
            errors << error(201, "no #{type} found between ##{a} and ##{b}")
          end
        end
      end
    end
  end

  # Download a file via HTTP given a URL.  Save it chunk-wise into a temp file,
  # return the name of the file, along with pertinent header information.
  def load_from_url(url) # :doc:
    tempfile = "#{RAILS_ROOT}/tmp/api_upload.#{$$}"
    header = {}
    uri = URI.parse(url)
    File.open(tempfile, 'w') do |fh|
      Net::HTTP.new(uri.host, uri.port).start do |http|
        http.request_get(uri.request_uri) do |response|
          response.read_body do |chunk|
            fh.write(chunk)
          end
          header['Content-Length'] = response['Content-Length'].to_i
          header['Content-Type']   = response['Content-Type']
          header['Content-MD5']    = response['Content-MD5']
        end
      end
    end
    return [tempfile, header]
  end
end

################################################################################
#
#  == MO API Exception Class
#
#  Each error has the following properties:
#
#  code::   Number code, e.g., 102 for syntax errors.
#  title::  Generic message, e.g., 'bad request syntax'.
#  msg::    Detailed message, e.g., 'invalid date, expect "YYYY-MM-DD"'.
#  fatal::  Was this a fatal error?
#
################################################################################

class MoApiException < StandardError
  attr_accessor :code, :msg, :fatal

  def initialize(args={})
    self.code  = args[:code]
    self.msg   = args[:msg]
    self.fatal = args[:fatal]
  end

  # Return corresponding "generic" error message.
  def title
    case code
    when 101 ; 'bad request method'
    when 102 ; 'bad request syntax'
    when 201 ; 'object not found'
    when 202 ; 'failed to create object'
    when 203 ; 'failed to update object'
    when 204 ; 'failed to delete object'
    when 301 ; 'authentication failed'
    when 302 ; 'permission denied'
    when 303 ; 'must authenticate'
    when 501 ; 'internal error'
    else       'unknown error'
    end
  end
end

################################################################################

# :stopdoc:
module ActiveRecord
  class Base
    class << self
      # This blasted thing is protected, so I have to create a public wrapper...
      def sanitize_sql_array_public(*args)
        sanitize_sql_array(*args)
      end
    end
  end
end

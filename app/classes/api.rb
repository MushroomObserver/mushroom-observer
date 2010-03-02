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

  # Basic SQL query used (if any).
  attr_accessor :query

  # What level of detail requested in response: :none, :low, :high
  attr_accessor :detail

  # Number of objects match query (if applicable).
  attr_accessor :number

  # Number of pages of results (if paginated).
  attr_accessor :page

  # Number of pages of results available.
  attr_accessor :pages

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
    @args = args
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
  #   api.query     Basic SQL query used (if any).
  #   api.detail    What level of detail requested in response: :none, :low, :high
  #   api.number    Number of objects match query (if applicable).
  #   api.page      Number of pages of results (if paginated).
  #   api.pages     Number of pages of results available.
  #
  def process
    begin

      # Return values.
      @objects = []
      @errors  = []

      # Make args available to other instance methods.
      @args = args

      # Get request method and action.
      raise error(101, "Missing method.") unless method = parse_arg(:method)
      raise error(102, "Missing action.") unless action = parse_arg(:action)
      action = action.to_s.downcase.to_sym
      method = method.to_s.downcase.to_sym

      # Converts :species_list to the class SpeciesList.
      table = action.to_s.pluralize
      model = action.to_s.camelize.constantize

      # Which mode are we running in?
      #  @safe - Trusted or admin mode.
      #  @user - User making request.
      #  @time - Time request was made.
      if @safe = parse_boolean(:_safe)
        @user = User.safe_find(parse_integer(:_user))
        @time = parse_time(:_time)
      else
        @user = authenticate(method != :get)
        @safe = parse_boolean(:auth_admin) if @user && @user.admin
      end

      # Create new object.
      if method == :post
        raise error(101, "POST method not yet available for #{action}.") \
          if !respond_to?("post_#{action}")
        if result = send("post_#{action}")
          @objects << result
        end

      # Lookup, update or delete existing objects.
      elsif [:get, :put, :delete].include?(method)
        raise error(101, "#{method.to_s.upcase} method not available for #{action}.") \
          if !respond_to?("#{method}_#{action}")

        # First parse query arguments.
        conds, tables, joins, max_page_len = send("get_#{action}")

        # Allow GET to paginate.
        if method == :get
          @page = parse_page
          page_len = parse_page_len(max_page_len)
        else
          @page = nil
          page_len = nil
        end

        # Get array of values to change for PUT.
        if method == :put
          sets = send("put_#{action}")
          if sets.is_a?(Hash) && sets.empty?
            raise error(102, "you didn't specify any values to change")
          else
            sets[:modified] = Time.now()
          end
        end

        # Let user request detail level.
        @detail = parse_enum(:detail, [:none, :low, :high]) || :none

        # No other arguments are allowed.
        error_if_any_other_args

        # Create lookup query.
        tables.unshift(table)
        tables = "FROM #{tables.join(', ')}"
        conds  = "WHERE #{conds.join(' AND ')}"
        conds  = '' if conds == 'WHERE '
        limit  = @page ? "LIMIT #{(@page-1)*page_len}, #{page_len}" : ''
        count_query = "SELECT COUNT(DISTINCT #{table}.id) #{tables} #{conds}"
        @query = "SELECT DISTINCT #{table}.id #{tables} #{conds} #{limit}"

        # Count total number of hits for GET.
        if method == :get
          @number  = model.connection.select_value(count_query).to_i
          @pages   = (@number.to_f / page_len).ceil
        end

        # Lookup ids using our SQL query.
        ids = model.connection.select_values(@query)
        make_sure_found_all_objects(ids, action)

        # Now let ActiveRecord load full objects (with eager-loading for GET).
        if method == :get && @detail == :high
          @objects = model.all(:conditions => ['id in (?)', ids], :include => joins)
        else
          @objects = model.all(:conditions => ['id in (?)', ids])
        end

        # Apply updates to all matching objects... carefully.
        if method == :put
          @objects.each do |x|
            id = x.id
            begin
              if x.user != @user
                @errors << error(302, "only owner may modify #{action} ##{id}")
              elsif !(sets.is_a?(Proc) ? sets.call(x) : x.update_attributes(sets))
                @errors << error(203, "failed to update #{action} ##{id}:\n#{x.formatted_errors}")
              end
            rescue => e
              @errors << convert_error(e, 203, "error occurred while updating #{action} ##{id}")
            end
          end

        # Delete matching objects... carefully.
        elsif method == :delete
          @objects.each do |x|
            id = x.id
            begin
              if x.user != @user
                @errors << error(302, "only owner may destroy #{action} ##{id}")
              elsif !send("delete_#{action}", x)
                @errors << error(204, "failed to destroy #{action} ##{id}:\n#{x.formatted_errors}")
              end
            rescue => e
              @errors << convert_error(e, 204, "error occurred while destroying #{action} ##{id}")
            end
          end
        end

      # Other random methods.
      else
        send("#{method}_#{action}")
      end
    rescue => e
      @errors << convert_error(e, 501, e.to_s, true)
    end

    return [@objects, @errors]
  end

  ##############################################################################
  #
  #  :section: GET Methods
  #
  #  These are responsible for parsing the "search" parameters and returning
  #  all the information necessary to create a SQL query.  In particular, they
  #  must each return four things:
  #
  #  conditions::   List of SQL fragments that form the "WHERE" clause.
  #  tables::       List of tables used in +conditions+.
  #  joins::        List of tables to :include when instantiating results (if eager-loading).
  #  max_page_len:: Maximum number of objects per page user is allowed to request.
  #
  #  Parsing is all done using several helper methods.  Here are some:
  #
  #  sql_id::           One or more ids or sync_ids.
  #  sql_date::         One or more dates or date ranges.
  #  sql_search::       Search pattern (only one allowed).
  #
  #  All of these return SQL fragments that encode the given condition(s).
  #
  #  Another handy method is:
  #
  #  uses_table?::    Does an SQL string use a given table?
  #
  #  This can be used to determine which additional tables need to be joined to
  #  in order to execute the given SQL query.
  #
  ##############################################################################

  def get_comment
    conds = []
    tables = []
    joins = [:user]

    conds += sql_id_or_name(:user, 'comments.user_id', 'users.login', 'users.name')

    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'comments.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = comments.user_id'
    end

    return [conds, tables, joins, 1000]
  end

  def get_image
    conds = []
    tables = []
    joins = [:user, :license]

    conds += sql_id_or_name(:user, 'images.user_id', 'users.login', 'users.name')

    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'images.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = images.user_id'
    end

    return [conds, tables, joins, 100]
  end

  def get_license
    conds = []
    tables = []
    joins = []

    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'licenses.id')

    return [conds, tables, joins, 1000]
  end

  def get_location
    conds = []
    tables = []
    joins = []

    conds += sql_id_or_name(:user, 'locations.user_id', 'users.login', 'users.name')

    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'locations.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = locations.user_id'
    end

    return [conds, tables, joins, 1000]
  end

  def get_name
    conds = []
    tables = []
    joins = [{:synonym => :names}]

    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'names.id')

    return [conds, tables, joins, 1000]
  end

  def get_naming
    conds = []
    tables = []
    joins = [:user, :observation, :name, :votes]

    conds += sql_id(:observation, 'namings.observation_id')
    conds += sql_id_or_name(:user, 'namings.user_id', 'users.login', 'users.name')
    conds += sql_id_or_name(:name, 'namings.name_id', 'names.text_name', 'names.search_name')

    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'namings.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = namings.user_id'
    end
    if uses_table?(conds, 'names')
      tables << :names
      conds << 'names.id = namings.name_id'
    end

    return [conds, tables, joins, 1000]
  end

  def get_observation
    conds = []
    tables = []
    joins = [
      :user,
      :location,
      {:name => {:synonym => :names}},
      {:namings => :name},
      {:images => [:user, :license]},
      {:comments => :user}
    ]

    conds += sql_date(:date, 'observations.when')
    conds += sql_id_or_name(:user, 'observations.user_id', 'users.login', 'users.name')
    conds += sql_id_or_name(:name, 'observations.name_id', 'names.text_name', 'names.search_name')
    conds += sql_id_or_name(:location, 'observations.location_id', 'observations.where', 'locations.name')
    conds += sql_search(:notes, 'observations.notes')
    conds << 'observations.thumb_image_id NOT NULL' if parse_arg(:has_image)
    conds << 'observations.specimen = TRUE'         if parse_arg(:has_specimen)

    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'observations.id')

    if uses_table?(conds, 'users')
      tables << :users
      conds << 'users.id = observations.user_id'
    end
    if uses_table?(conds, 'names')
      tables << :names
      conds << 'names.id = observations.name_id'
    end
    if uses_table?(conds, 'locations')
      tables << :locations
      conds << 'locations.id = observations.location_id'
    end

    return [conds, tables, joins, 100]
  end

  def get_user
    conds = []
    tables = []
    joins = [:location, :image]

    conds += sql_search(:name, 'users.login', 'users.name')

    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'users.id')

    return [conds, tables, joins, 1000]
  end

  def get_vote
    conds = []
    tables = []
    joins = []

    @something_besides_ids = true if !conds.empty?
    conds += sql_id(:id, 'votes.id')

    return [conds, tables, joins, 10000]
  end

  ##############################################################################
  #
  #  :section: PUT Methods
  #
  #  These are responsible for parsing all the "set" parameters and returning a
  #  hash that will be passed into <tt>object.write_attributes(args)</tt>.  If
  #  write_attributes is not sufficiently flexible, method may elect to return
  #  a lambda proc instead, which will perform the update once the objects are
  #  ready.
  #
  #    # Comments are simple: you can change summary and content, and that's it.
  #    def put_comment
  #      return {
  #       :summary => params[:set_summary],
  #       :content => params[:set_content],
  #      }
  #    end
  #
  #    # Votes are changed using a different method.
  #    def put_vote
  #      new_value = params[:set_value]
  #      lambda do |vote|
  #        old_value = vote.value
  #        if new_value == old_value
  #          # Return "trivial" success if no change.
  #          return true
  #        else
  #          # Returns true if successful.  Note that @user refers to the user
  #          # (authenticated) making this change.
  #          return vote.naming.change_vote(@user, val)
  #        end
  #      end
  #    end
  #
  #  These methods all rely heavily on a large set of very useful helpers that
  #  parse and validate the "set_blah" parameters.  Here are several:
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
  #  appropriately cast value if valid, or nil if the parameter wasn't
  #  specified.
  #
  ##############################################################################

  def put_comment
    sets = {}
    sets[:summary] = x if x = parse_string(:set_summary, 100)
    sets[:content] = x if x = parse_string(:set_content)
    return sets
  end

  def put_image
    sets = {}
    sets[:date]             = x if x = parse_date(:set_date)
    sets[:notes]            = x if x = parse_string(:set_notes)
    sets[:copyright_holder] = x if x = parse_string(:set_copyright_holder, 100)
    sets[:license]          = x if x = parse_object(:set_license, License)
    return sets
  end

  # def put_location
  #   TODO
  # end

  # def put_name
  #   TODO
  # end

  def put_naming
    sets = {}
    sets[:name] = x if x = parse_object(:set_name, Name)
    for num in Naming::Reason.all_reasons
      if x = parse_string("set_reason_#{num}".to_sym)
        sets["reason_#{num}".to_sym] = x
      end
    end

    # Changing name and/or reasons is non-trivial.
    if !sets.empty?
      vals = sets
      sets = lambda do |naming|

        # Change name.
        if (new_name = vals[:name]) && (naming.name != new_name)
          if naming.observation.name_been_proposed?(new_name)
            @errors << error(203, "name #{new_name.id} has already been proposed (naming ##{naming.id})")
          elsif !naming.editable?
            @errors << error(203, "not allowed to change naming ##{naming.id} since at least one other user has given it a positive vote")
          else
            if update_naming_object(naming, new_name, true)
              # Invalidate votes if name changed.
              for vote in naming.votes
                vote.destroy if vote.user_id != @user.id
              end
              naming.observation.reload
              naming.observation.calc_consensus(@user)
            end
          end
        end

        # Update reasons.
        for reason in naming.get_reasons
          if val = vals["reason_#{reason.num}".to_sym]
            reason.notes = val
          else
            reason.delete
          end
        end
      end
    end

    return sets
  end

  def put_observation
    sets = {}
    if x = parse_object(:set_location, Location)
      sets[:location] = x
      sets[:where]    = nil
    end
    sets[:date]                   = x if x = parse_date(:set_date)
    sets[:notes]                  = x if x = parse_string(:set_notes)
    sets[:thumbnail]              = x if x = parse_object(:set_thumbnail, Image)
    sets[:specimen]               = x if x = parse_boolean(:set_specimen)
    sets[:is_collection_location] = x if x = parse_boolean(:set_is_collection_location)
    return sets
  end

  # def put_user
  #   TODO
  # end

  def put_vote
    sets = {}
    if val = parse_vote(:set_value)
      # Return a proc that changes the vote.
      sets = lambda do |vote|
        result = false
        if vote.value == val
          # Return "trivial" true if value is already correct.
          result = true
        else
          # Otherwise return true if vote is successfully changed.
          result = vote.naming.change_vote(@user, val)
        end
        return result
      end
    end
    return sets
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

  def delete_comment(comment)
    return comment.destroy(@user)
  end

  def delete_image(image)
    return image.destroy(@user)
  end

  def delete_naming(naming)
    result = false
    if !naming.deletable?
      @errors << error(204, "not allowed to delete naming ##{naming.id} from observation ##{naming.observation_id}")
    elsif !naming.destroy(@user)
      @errors << error(204, "failed to delete naming ##{naming.id} from observation ##{naming.observation_id}")
    else
      result = true
    end
    return result
  end

  def delete_observation(observation)
    return observation.destroy(@user)
  end

  def delete_vote(vote)
    result = false
    if vote.naming.user == @user
      @errors << error(204, "cannot delete your vote (##{vote.id}) on your own naming (##{vote.naming_id})")
    else
      result = vote.naming.change_vote(@user, Vote.delete_vote)
    end
    return result
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
  #  <tt>@user</tt>::       User posting the new object.
  #  <tt>@time</tt>::       Time request was _submitted_ (if not now).
  #  <tt>@args[:http_request_body]</tt>::
  #                          This is where an image comes in from HTTP post.
  #
  #  These methods all rely heavily on a large set of very useful helpers that
  #  parse and validate the "set_blah" parameters.  Here are several:
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
  #  appropriately cast value if valid, or nil if the parameter wasn't
  #  specified.
  #
  ##############################################################################

  def post_comment
    now     = Time.now
    summary = parse_string(:summary, 100)
    content = parse_string(:content)
    object  = parse_object(:observation, Observation)

    summary ||= '.'
    content ||= ''

    raise error(102, 'missing content') if !content
    raise error(102, 'missing object')  if !object

    comment = Comment.new(
      :created  => now,
      :modified => now,
      :user     => @user,
      :summary  => summary,
      :comment  => content,
      :object   => object
    )
    raise error(202, comment.formatted_errors) if !comment.save
    if object.respond_to?(:log)
      object.log(:log_comment_added, :summary => summary)
    end
    return comment
  end

  def post_image
    temp = nil

    now              = Time.now
    url              = parse_string(:url)
    file             = parse_string(:file)
    date             = parse_date(:date)
    notes            = parse_string(:notes)
    copyright_holder = parse_string(:copyright_holder, 100)
    license          = parse_object(:license, License)
    observation      = parse_object(:observation, Observation)

    date             ||= observation.when if observation
    notes            ||= ''
    copyright_holder ||= @user.legal_name
    license          ||= @user.license

    raise error(102, 'missing date') if !date
    raise error(102, 'cannot use both url and file') if url && file
    raise error(102, 'only jason can use file') if file && @user.login != 'jason'
    raise error(102, 'expected file to be "name.jpg"') if file && !file.match(/^[\w\.\-]+\.jpg$/)

    if url
      temp, header   = load_from_url(url)
      io             = File.open(temp, 'r')
      content_length = header['Content-Length']
      content_type   = header['Content-Type']
      content_md5    = header['Content-MD5']
    elsif file
      file           = "/home/jason/images/#{file}"
      io             = File.open(file, 'r')
      content_length = File.size(file)
      content_type   = 'image/jpeg'
    else
      request = @args[:http_request_body]
      io             = request.body
      content_length = request.content_length
      content_type   = request.content_type
      content_md5    = request.headers['Content-MD5']
    end

    image = Image.new(
      :created          => now,
      :modified         => now,
      :user             => @user,
      :when             => date,
      :notes            => notes,
      :copyright_holder => copyright_holder,
      :license          => license,
      :image            => io,
      :content_length   => content_length,
      :content_type     => content_type,
      :content_md5      => content_md5
    )
    raise error(202, image.formatted_errors) if !image.save || !image.save_image
    observation.add_image_with_log(image, @user) if observation
    return image

  ensure
    # Make sure the temp file is deleted.
    File.delete(temp) if temp
  end

  def post_location
    now   = Time.now
    name  = parse_string(:name, 200)
    notes = parse_string(:notes)
    north = parse_float(:north)
    south = parse_float(:south)
    east  = parse_float(:east)
    west  = parse_float(:west)
    high  = parse_float(:high)
    low   = parse_float(:low)

    notes ||= ''

    raise error(102, 'missing name')  if !name
    raise error(102, 'missing north') if !north
    raise error(102, 'missing south') if !south
    raise error(102, 'missing east')  if !east
    raise error(102, 'missing west')  if !west
    raise error(102, 'missing high')  if !high
    raise error(102, 'missing low')   if !low

    location = Location.new(
      :created          => now,
      :modified         => now,
      :user             => @user,
      :display_name     => name,
      :notes            => notes,
      :north            => north,
      :south            => south,
      :east             => east,
      :west             => west,
      :high             => high,
      :low              => low
    )
    raise error(202, location.formatted_errors) if !location.save
    return location
  end

  def post_name
    rank       = parse_rank(:rank)
    name_str   = parse_string(:name, 100)
    author     = parse_string(:author, 100)
    citation   = parse_string(:citation)
    deprecated = parse_boolean(:deprecated)
    notes      = {}
    for f in Name.all_note_fields
      notes[f] = parse_string(f)
    end

    raise error(102, 'missing rank') if !rank
    raise error(102, 'missing name') if !name_str

    # Make sure name doesn't already exist.
    match = nil
    if author && author != ''
      match = Name.find_by_text_name_and_author(name_str, author)
      name_str2 = "#{name_str} #{author}"
    else
      match = Name.find_by_text_name(name_str)
      name_str2 = name_str
    end
    raise error(202, "name already exists") if match

    # Make sure the name parses.
    names = Name.names_from_string(name_str2)
    name = names.last
    raise error(202, "invalid name") if name.nil?

    # Fill in information.
    name.created  = now
    name.modified = now
    name.rank     = rank
    name.citation = citation
    name.change_text_name(name_str, author, rank)
    name.change_deprecated(true) if deprecated
    for f in notes.keys
      name.send("#{f}=", notes[f])
    end

    # Save it and any implictly-created parents (e.g. genus when creating
    # species for unrecognized genus).
    for name in names
      if name
        name.user = @user
        name.modified = now
        name.save
        name.add_editor(@user)
      end
    end
    return names.last
  end

  def post_naming
    now            = Time.now
    name           = parse_object(:name, Name)
    observation    = parse_object(:observation, Observation)
    vote           = parse_vote(:vote)
    reasons = {}
    for num in Naming::Reason.all_reasons
      reasons[num] = parse_string("reason_#{num}")
    end

    raise error(102, 'missing name')        if !name
    raise error(102, 'missing observation') if !observation
    raise error(102, 'missing vote')        if !vote

    naming = Naming.new(
      :created     => now,
      :modified    => now,
      :observation => observation,
      :name        => name,
      :user        => @user,
      :set_reasons => reasons
    )
    raise error(202, naming.formatted_errors) if !naming.save

    # Attach vote.
    naming.observation.change_vote(naming, vote)

    return naming
  end

  def post_observation
    now                    = Time.now
    date                   = parse_date(:date)
    where                  = parse_string(:where)
    location               = parse_object(:location, Location)
    specimen               = parse_boolean(:specimen)
    is_collection_location = parse_boolean(:is_collection_location)
    notes                  = parse_string(:notes)
    thumbnail              = parse_object(:thumbnail, Image)
    images                 = parse_objects(:images, Image)

    date                   ||= now
    is_collection_location ||= true
    notes                  ||= ''
    where = location.display_name if location

    raise error(102, 'missing location') if !location

    obs = Observation.new(
      :created                => now,
      :modified               => now,
      :when                   => date,
      :user                   => @user,
      :place_name             => where,
      :specimen               => specimen,
      :is_collection_location => is_collection_location,
      :notes                  => notes,
      :thumbnail_image        => thumbnail
    )
    raise error(202, obs.formatted_errors) if !obs.save
    obs.log(:log_observation_created)
    obs.images += images if !images.empty?
    return obs
  end

  def post_vote
    naming = parse_object(:naming, Naming)
    value  = parse_vote(:value)

    raise error(102, 'missing naming') if !naming
    raise error(102, 'missing vote')   if !vote

    naming.change_vote(@user, vote)
    return Vote.find_by_user_and_naming(@user, naming)
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
    if @args[name].to_s != ''
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
  def parse_object(arg, model) # :doc:
    result = nil
    if x = parse_arg(arg)
      if x.match(/^\d+$/)
        begin
          result = model.find(x.to_i)
        rescue
          raise error(102, "#{arg}=#{x} was not found")
        end
      else
        raise error(102, "#{arg} must be integer id")
      end
    end
    return result
  end

  # Parse and validate an object id, returning id instead of object.  This is a
  # useful method if set_image=0 means something different from omitting the
  # argument altogether.  (Note, it still does a 'find' to verify it exists.)
  def parse_object_id(arg, model) # :doc:
    result = nil
    if x = parse_arg(arg)
      if x == '0'
        result = 0
      elsif x.match(/^\d+$/)
        begin
          result = model.find(x.to_i).id
        rescue
          raise error(102, "#{arg}=#{x} was not found")
        end
      else
        raise error(102, "#{arg} must be integer id")
      end
    end
    return result
  end

  # Parse and validate a list of object ids.
  def parse_objects(arg, model) # :doc:
    result = []
    if x = parse_arg(arg)
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
            @errors << error(201, "#{type} ##{x} not found")
          end
        elsif x.match(/^(\d+)-(\d+)$/)
          a, b = $1.to_i, $2.to_i
          a, b = b, a if a > b
          if !ids.any? {|x| x.to_i >= a || x.to_i <= b}
            @errors << error(201, "no #{type} found between ##{a} and ##{b}")
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
# :startdoc:

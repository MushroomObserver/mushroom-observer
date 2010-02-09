#
#  = Query Model
#
#  This model encapsulates a database query that looks up one or more objects
#  of a given type that match certain conditions in a certain order.  Queries
#  are dyamically joined with any number of additional tables, are required by
#  sorting and selection conditions.
#
#  Queries are specified by a model and flavor.  The model specifies which kind
#  of objects are being requests, e.g. :Name or :Observation.  The flavor
#  summarizes the type of search, e.g. :all or :at_location.  Only certain
#  flavors are allowed for a given model.  For example, it makes no sense to
#  request comments sorted by name since they have no name.
#
#  Each model has a default search flavor (:default), which is used by the prev
#  and next actions when the specified query no longer exists.  For example, if
#  you click on an observation from the main index, prev and next travserse the
#  results of an :Observation :by_rss_log query.  If the user comes back a day
#  later, this query will have been culled by the garbage collector (see
#  below), so prev and next need to be able to create a default query on the
#  fly.  In this case it may be :Observation :all (see default_flavors array
#  below).
#
#  In addition, some queries require additional parameters.  For example,
#  :Comment :for_user requires a user_id (it retrieves comments posted on a
#  given user's observations).  These parameters are saved along-side the model
#  and flavor, and together the three fully-specify a query so that it may be
#  recreated and executed at a later time, even potentially by another user
#  (e.g., if users share links that have query specs embedded in them).
#
#  == Example Usage
#
#  Get observations created by @user.
#
#    query = Query.lookup(:Observation, :by_user, :user => @user)
#
#  Get observations in the three sections of show_name:
#  1) observations whose consensus is @name
#  2) observations whose consensus is synonym of @name
#  3) observations with non-consensus naming that is a synonym of @name
#
#    query = Query.lookup(:Observation, :of_name, :name => @name)
#    query = Query.lookup(:Observation, :of_name, :name => @name, :synonyms => :exclusive)
#    query = Query.lookup(:Observation, :of_name, :name => @name, :synonyms => :all, :nonconsensus => :exclusive)
#
#  You may further tweak a query after it's been created:
#
#    query = Query.lookup(:Observation)
#    query.join  << :names
#    query.where << 'names.correct_spelling_id IS NULL'
#    query.order =  'names.search_name ASC'
#
#  Now you may execute it in various ways:
#
#    num_results = query.num_results
#    ids         = query.result_ids
#    instances   = query.results
#
#  You also have access to lower-level operations:
#
#    ids   = query.select_values(:where => 'names.observation_name LIKE "A%"')
#    ids   = query.select_values(:order => 'names.search_name ASC')
#    names = query.select_values(:select => 'names.observation_name')
#
#    # This is the most efficient way to make Query work with ActiveRecord --
#    # This lets you customize the query, then automatically tells it to select
#    # all the fields ActiveRecord::Base#find_by_sql needs.
#    names = query.find_by_sql(:where => ...)
#
#  Sequence operators let you use the query as a pseudo-iterator:  (Note, these
#  are somewhat more subtle that shown here, as nested queries may require the
#  creation of new query instances.  See the section on nested queries below.)
#
#    query = Query.lookup(:Observation)
#    query.this = @observation
#    next  = query.this if query.next
#    this  = query.this if query.prev
#    prev  = query.this if query.prev
#    first = query.this if query.first
#    last  = query.this if query.last
#
#  Finally, Query's know how to work with Paginator's:
#
#    # In controller:
#    query = create_query(:Name)
#    @pages = paginate_numbers
#    @names = query.paginate(@pages)
#
#    # Or if you want to paginate by letter first, then page number:
#    query = create_query(:Name)
#    @pages = paginate_letters
#    @names = query.paginate(@pages, :letter_field => 'names.search_name')
#
#  == Sequence Operators
#
#  The "correct" usage of the sequence operators is subtle and inflexible due
#  to the complexities of the query potentially being nested.  This is how it
#  is designed to work:
#
#    query = Query.find(id) || Query.lookup(:Image)
#
#    # Note that query.next *MAY* return a clone.
#    if new_query = query.next
#      puts "Next image is: " + new_query.this_id
#    else
#      puts "No more images."
#    end
#
#    # Must reset otherwise query.prev just goes back to original place.
#    query.reset
#    if new_query = query.prev
#      puts "Previous image is: " + new_query.this_id
#    else
#      puts "No more images."
#    end
#
#    # Note: query.last works the same.
#    if new_query = query.first
#      puts "First image is: " + new_query.this_id
#    else
#      puts "There are no matching images!"
#    end
#
#  == Nested Queries
#
#  Queries are allowed to be nested inside other queries.  This is a tricky,
#  nasty bit of chicanery that allows us to do things like step through all of
#  the images of the results of an observation search.
#
#  The critical problem here is that in a nested query like this, the results
#  are no longer guaranteed to be unique.  This is a problem because the
#  sequence operators rely on being able to find out where it is in the results
#  based on the result id.  If that result occurs more than once, this
#  reverse-lookup is no longer well-defined (ambiguous).
#
#  Instead, each inner query (images for a single observation in the example
#  above) lives only for a single result of the outer query.  If you query the
#  results of the inner query, you only get the results for the current outer
#  result (only the images for a single observation).
#
#  The sequence operators, however, know how to communicate with the outer
#  query, so inner.next will step right off the end of the present inner query,
#  request outer.next, and go to the first result of the new inner query.
#
#  The unfortunate side-effect of this behavior is that inner.next has to
#  replace the inner query.  This would invalidate any urls that refer to the
#  old inner query.  Instead we have inner.next return a *clone* of the old
#  inner query if it needs to change it.
#
#  This is how it should work: (this code would be in a controller, with access
#  to the handy helper method ApplicationController#find_or_create_query)
#
#    # The setup all happens in show_observation:
#    outer = find_or_create_query(:Observation)
#    inner = create_query(:Image, :inside_observation, :outer => outer,
#                         :observation => @observation)
#    for image in inner.results
#      link_to(image, :action => 'show_image', :id => image.id,
#              :params => query_params(inner))
#    end
#
#    # Now show_image can be oblivous:
#    query = find_or_create_query(:Image)
#    link_to('Prev', :action => 'prev_image', :id => image.id,
#            :params => query_params(query))
#    link_to('Next', :action => 'next_image', :id => image.id,
#            :params => query_params(query))
#    link_to('Back', :action => 'show_observation', :id => image.id,
#            :params => query_params(query))
#
#    # And this is how prev and next work:
#    query = find_or_create_query(:Image, :this => params[:id])
#    if new_query = query.next
#      redirect_to(:action => 'show_image', :id => new_query.this_id,
#                  :params => query_params(new_query))
#    else
#      flash_error 'No more images!'
#    end
#
#  *NOTE*: The inner query knows about the outer query.  So, when show_image
#  links back to show_observation (see above), and show_observation looks up
#  the inner query, even though the inner query is an image query, it should
#  still know to use the outer query.  (Normally, show_observation would throw
#  away any non-observation-based query it is passed.)
#
#  == Caching
#
#  It caches results, result_ids and num_results.  If you call results, it will
#  populate the other two, however, if you only require the count (num_results)
#  or the ids (result_ids) it will not populate result_ids and results,
#  respectively.  Note that because of this paginate will only populate
#  num_results.  TODO -- it should populate the others if there is only one
#  page of results, though!
#
#  The next and prev sequence operators always grab the entire set of
#  result_ids.  No attempt is made to reduce the query.  TODO - we might be
#  able to if we can turn the ORDER clause into an upper/lower bound.
#
#  The first and last sequence operators ignore result_ids (TODO no need to
#  ignore if not nested or if outer is already at end).  However, they are able
#  to execute optimized queries that return only the first or last result.
#
#  None of the low-level queries are cached in any way.
#
#  == Attributes
#  ==== Database attributes
#  model::              Class of model results belong to.
#  model_symbol::       (same, as Symbol)
#  model_string::       (same, as String)
#  flavor::             Type of query (Symbol).
#  outer::              Outer Query (if nested).
#  params::             Serialized hash of parameters used to create query.
#  user::               User that created.
#  user_id::            (same, as id)
#  modified::           Last time it was used.
#  access_count::       Number of times its been used.
#
#  ==== Local attributes
#  this::               Current location in query (for sequence operators).
#  join::               Tree of tables used in query.
#  tables::             Extra tables which have been joined explicitly.
#  where::              List of WHERE clauses in query.
#  group::              GROUP BY clause in query.
#  order::              ORDER BY clause in query.
#
#  == Class Methods
#  lookup::             Lookup a Query, creating it if necessary (unsaved)
#  lookup_and_save::    Same, but save it, too.
#  cleanup::            Do garbage collection on old or unused Query's.
#
#  ==Instance Methods
#  initialized?::       Has this query been initialized?
#  coerce::             Coerce a query for one model into a query for another.
#  is_coercable?::      Check if +coerce+ will work (but don't actually do it).
#
#  ==== Sequence operators
#  first::              Go to first result.
#  prev::               Go to previous result.
#  next::               Go to next result.
#  last::               Go to last result.
#  reset::              Go back to original result.
#
#  ==== Query Operations
#  query::              Build SQL query.
#  query_all::          Build SQL query for ActiveRecord::Base#find_by_sql.
#  select_count::       Execute query after wrapping select clause in COUNT().
#  select_value::       Call model.connection.select_value.
#  select_values::      Call model.connection.select_values.
#  select_rows::        Call model.connection.select_rows.
#  select_one::         Call model.connection.select_one.
#  select_all::         Call model.connection.select_all.
#  find_by_sql::        Call model.find_by_sql.
#  tables_used::        Array of tables used in query (Symbol's).
#  uses_table?::        Does the query use this table?
#  num_results::        Number of results the query returns.
#  results::            Array of all results, instantiated.
#  result_ids::         Array of all results, just ids.
#  index::              Index of a given id or object in the results.
#  paginate::           Array of subset of results, instantiated.
#  paginate_ids::       Array of subset of results, just ids.
#  clear_cache::        Clear results cache.
#
#  ==== Outer queries
#  outer::              Outer Query (if nested).
#  has_outer?::         Is this Query nested?
#  get_outer_this_id::  Get outer Query's current id.
#  outer_first::        Call +first+ on outer Query.
#  outer_prev::         Call +prev+ on outer Query.
#  outer_next::         Call +next+ on outer Query.
#  outer_last::         Call +last+ on outer Query.
#  new_inner::          Create new inner Query based the given outer Query.
#  new_inner_if_necessary::
#                       Create new inner Query if the outer Query has changed.
#
#  == Internal Variables
#
#  ==== Class Variables
#  @@last_cleanup::     Time: last time database was cleaned up.
#  @@default_required_params:: Default required parameters declarations.
#
#  ==== Instance Variables
#  @initialized::       Boolean: has +initialize_query+ been called yet?
#  @model_class::       Class: associated model.
#  @this_id::           Fixnum: current place in results.
#  @save_this_id::      Fixnum: saved copy of +@this_id+ for +reset+.
#  @result_ids::        Array of Fixnum: all results.
#  @results::           Hash: maps ids to instantiated records.
#  @outer::             AbstractQuery: cached copy of outer query (nested
#                       queries only).
#  @params_cache::      Hash: where instances passed in via params are cached.
#
################################################################################

class AbstractQuery < ActiveRecord::Base
  self.abstract_class = true

  # Parameters are kept in a Hash, possibly with Arrays as values.
  serialize :params, Hash

  # Low-level description of SQL query.
  attr_accessor :join, :tables, :where, :group, :order

  # Prevent SQL statements from getting absurdly large.  Any "id IN (...)"
  # conditions are limited to this number of values.
  MAX_ARRAY = 1000

  ##############################################################################
  #
  #  :section: Configuration
  #
  ##############################################################################

  # Default flavor (requiring no params) for each model.  The default, should
  # none be found in this hash, is :all.
  #
  #   self.default_flavors = {
  #     :User     => :active,
  #     :Location => :defined,
  #   }
  #
  superclass_delegating_accessor :default_flavors
  self.default_flavors = {}

  # Parameters required for each flavor.  The keys are the parameter names, the
  # values are the "declaration".  An example explains it pretty well:
  #
  #   self.required_params = {
  #     :by_user   => {:user => User}
  #     :with_name => {:name => Name, :optional_flag? => :boolean}
  #     :in_set    => {:ids => [:id]}
  #     :pattern   => {:pattern => :string, :mode? => {:string => [:simple, :complex]}}
  #   }
  #
  # The question marks mean "optional" -- they are not actually part of the
  # parameter names.  The possible declarations are:
  #
  # * :boolean -- true or false
  # * :id -- positive integer
  # * :integer -- any integer
  # * :float -- floating point
  # * :string -- string (or symbol)
  # * ActiveRecord -- either a subclass of the given class or an id
  # * Array -- array of one of the above, given by the first (only) value
  #
  # Enumeration: You can limit the values of a base type by giving a Hawh.  It
  # should have only one key/val pair; the key is the base type (any of the
  # above except Array), the value is an Array of acceptable values (of the
  # appropriate type).  If the base type is :string, you may also list values
  # as regular expressions.  (Strings: if the accepted values are symbols, the
  # user-supplied parameter will be converted to symbol; if they are strings,
  # they will be converted to strings.)
  #
  # Additional types: You may define additional types in your subclass.  Just
  # define methods called <tt>validate_<type>(arg, val)</tt>.
  #
  superclass_delegating_accessor :required_params
  self.required_params = {}
  @@default_required_params = {:ids => [:id]}

  # Allowed flavors for each model.  Just a hash mapping model (symbols) to
  # arrays of allowed flavors (also symbols).
  #
  #   self.allowed_model_flavors = {
  #     :User => [ :all, :active, :with_photo ],
  #     :Image => [ :all, :recent, :reviewed ],
  #   }
  #
  superclass_delegating_accessor :allowed_model_flavors
  self.allowed_model_flavors = {}

  # This table maps each pair of tables to the foreign key name:
  #
  #   # Standard join:
  #   join_conditions[:observations][:names] => :name_id
  #   # Means: 'observations.name_id = names.id'
  #
  #   # "Alternate" join: (images can join to users via owner or reviewer)
  #   join_conditions[:images][:'users.owners']    => :owner_id
  #   join_conditions[:images][:'users.reviewers'] => :reviewer_id
  #   # Means: 'images.owner_id    = users.id'
  #   #   -or- 'images.reviewer_id = users.id'
  #
  #   # Polymorphic join: (any field that doesn't end in "id")
  #   join_conditions[:comments][:images] => :object
  #   # Means: 'comments.object_id = images.id AND
  #             comments.object_type = "Image"'
  #
  superclass_delegating_accessor :join_conditions
  self.join_conditions = {}

  # This is the order in which we should list tables, smallest first.  Any
  # tables not listed in here get stuck at the end, alphabetically.
  superclass_delegating_accessor :table_order
  self.table_order = []

  # Add these to the list of required parameters.  For example, it you want
  # all queries for a given model add an optional parameter:
  #
  #   def extra_parameters
  #     if model_symbol == :Name
  #       {:include_synonyms? => :boolean}
  #     end
  #   end
  #
  def extra_parameters; nil; end

  # This gives the subclass opportunity to make extra global initializations
  # *after* flavor-specific initializations.  The following three global
  # initializations cannot be overridden:
  #
  # +join+::  Joins to additional table(s).
  # +where+:: Adds extra condition(s) to WHERE condition.
  # +order+:: Overrides ORDER BY clause.
  #
  def extra_initialization; end

  # Returns the default sort order for the query.  This should be recognized
  # by the <tt>:by => :order</tt> parameter, as handled by +initialize_order+
  # "callback".  The "default" default is 'id'.  (It should always return a
  # String, not a Symbol!)
  #
  #   def default_order
  #     case flavor
  #     when :contribution
  #       'user_login'
  #     else
  #       'modified'
  #     end
  #   end
  #
  def default_order; 'id'; end

  # This is where you define what the various <tt>:by => :order</tt> sort
  # orders mean.  Several trivial orders are defined by default, but can be
  # overridden in this method:
  #
  # * 'modified', 'created', 'date' -- sorts by the column of the same name,
  #   in descending order.
  #
  # * 'name', 'title', 'login' -- sorts by the column of the same name, in
  #   ascending order.
  #
  # * 'id' -- sorts by object id, in ascending order.
  #
  # *NOTE*: The <tt>params[:order]</tt> value is a String, not a Symbol!
  #
  # Example:
  #
  #   def initialize_order(by)
  #     table = model.table_name
  #     case by
  #     when 'user_login'
  #       self.join << :user
  #       "users.login ASC'
  #     end
  #   end
  #
  def initialize_order(by); nil; end

  # This gives inner queries the ability to tweak the outer query.  For
  # example, this is a handy way to tell the outer query to skip outer results
  # that result in empty inner queries.
  #
  # This instance variabl is a Proc, initialized in the flavor-specific
  # initializer:
  #
  #   def initialize_inside_user
  #     ...
  #     self.tweak_outer_query = lambda do |outer|
  #       # This tells the outer query only to include users that have images
  #       # (i.e. have entries in the "images_users" many-to-many glue table).
  #       (outer.params[:join] ||= []) << :images_users
  #     end
  #   end
  #
  attr_accessor :tweak_outer_query

  # Each inner query corresponds to a single result of the outer query.  This
  # lets the inner query tell the corresponding +this_id+ of the outer
  # query.  By default, it gets it from a parameter of the same name as the
  # outer's model (e.g., <tt>params[:user]</tt> for inner queries nested inside
  # :User queries).
  #
  # This instance variable is a Proc, initialized in the flavor-specific
  # initializer.  For example, the default would look like this:
  #
  #   def initialize_inside_user
  #     ...
  #     self.outer_this_id = lambda do |inner|
  #       inner.params[:user]
  #     end
  #   end
  #
  attr_accessor :outer_this_id

  # This tells us how to create a new inner query based on another result of
  # the same outer query.  This is called, for example, when using the sequence
  # operators on an inner query.  When it runs out of results for the inner
  # query, it goes to the next result in the outer query, and creates a new
  # inner query corresponding to it.  By default, it just stores the outer
  # result (<tt>outer.this_id</tt>) in a parameter with the same name as the
  # outer query's model (e.g., <tt>params[:user] = outer.this_id</tt> for inner
  # queries nested inside :User queries).
  #
  # This instance variable is a Proc, initialized in the flavor-specific
  # initializer.  For example, the default would look like this:
  #
  #   def initialize_inside_user
  #     ...
  #     self.setup_new_inner_query = lambda do |new_params, new_outer|
  #       new_params[:user] = new_outer.this_id
  #     end
  #   end
  #
  attr_accessor :setup_new_inner_query

  ##############################################################################
  #
  #  :section: Model Disambiguation
  #
  ##############################################################################

  # Set model attribute.  Takes Class, Symbol or String:
  #
  #   query.model = User
  #   query.model = :User
  #   query.model = 'User'
  #
  def model=(x)
    x = x.to_s.constantize if !x.is_a?(Class)
    @model_class = x
    write_attribute('model', x.to_s.to_sym)
  end

  # Returns model attribute as Class.
  def model
    @model_class ||= read_attribute('model').to_s.constantize rescue nil
  end

  # Returns model attribute as String.
  def model_string
    model.to_s
  end

  # Returns model attribute as Symbol.
  def model_symbol
    model.to_s.to_sym
  end

  # Models that we define queries for (Array of Symbols).  This is used to
  # declare the database enum column.
  def self.all_models
    allowed_model_flavors.keys.sort_by(&:to_s)
  end

  # All possible query flavors, mashing them together for all the models (Array
  # of Symbols).  This is used to declare the database enum column.
  def self.all_flavors
    allowed_model_flavors.values.flatten.uniq.sort_by(&:to_s)
  end

  ##############################################################################
  #
  #  :section: Construction
  #
  ##############################################################################

  # Look up record with given ID, returning nil if it no longer exists.
  def self.safe_find(id)
    begin
      self.find(id)
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  # Instantiate and save a new query.
  def self.lookup_and_save(*args)
    query = lookup(*args)
    query.save!
    query
  end

  # Instantiate new query for a given model and flavor.
  def self.lookup(model, flavor=:default, params={})
    query = new()

    # Periodically clean out old queries.
    if !defined?(@@last_cleanup) or
       (@@last_cleanup < Time.now - 5.minutes)
      if RAILS_ENV != 'test'
        self.cleanup
        @@last_cleanup = Time.now
      end
    end

    # Provide default flavor.
    if flavor == :default || flavor == ''
      flavor = default_flavors[model.to_s.to_sym] || :all
    end

    # Make sure this is a recognized query type.
    model = model.to_s.to_sym
    if !allowed_model_flavors.has_key?(model)
      raise("Invalid model: '#{model}'")
    elsif !allowed_model_flavors[model].include?(flavor)
      raise("Invalid query for #{model} model: '#{flavor}'")
    end

    # Let caller combine lookup and this= in one call.
    if arg = params[:this] || params[:this_id]
      params.delete(:this)
      params.delete(:this_id)
      set_this = arg
    end

    # Initialize attributes, but don't create query or do anything yet.
    query.attributes = {
      :model        => model,
      :flavor       => flavor,
      :params       => params,
      :user         => User.current,
      :modified     => Time.now,
      :access_count => 0,
    }

    # Make sure all required params exist and are valid; also make sure there
    # aren't any unexpected arguments.
    query.validate_params

    # See if such a query already exists and use it instead.
    str = YAML::dump(query.params)
    if other = find_by_model_and_flavor_and_params(model, flavor, str)
      query = other
    end

    # Okay to set "this" now.
    if set_this
      query.this = set_this
    end

    return query
  end

  # Only keep unused states around for an hour, and used states for a day.
  # This goes through the whole lot and destroys old ones.
  def self.cleanup
    connection.delete %(
      DELETE FROM #{table_name}
      WHERE access_count = 0 AND modified < DATE_SUB(NOW(), INTERVAL 6 HOUR) OR
            access_count > 0 AND modified < DATE_SUB(NOW(), INTERVAL 1 DAY)
    )
  end

  ##############################################################################
  #
  #  :section: Coercion
  #
  ##############################################################################

  # Attempt to coerce a query for one model into a related query for another
  # model.  This is currently only defined for a very few specific cases.  I
  # have no idea how to generalize it.  Returns a new Query in rare successful
  # cases; returns +nil+ in all other cases.  *NOTE*: It does not save the
  # new query if it has to create a new one!
  def coerce(new_model, just_test=false)

    # Just handle the trivial case -- model's not actually different!
    if model_string == new_model.to_s
      self
    else
      nil
    end
  end

  # Can this query be coerced into a query for another type of object?
  def is_coercable?(new_model)
    !!coerce(new_model, :just_test)
  end

  ##############################################################################
  #
  #  :section: Validation
  #
  ##############################################################################

  # Make sure caller passed in all the necessary params (and no extras!)
  # Replaces the +params+ Hash with a new, correct one.
  def validate_params
    old_args = params.dup
    new_args = {}

    # Get the parameters declarations for this flavor.
    reqs = required_params[flavor] || @@default_required_params[flavor] || {}

    # Let the subclass declare some additional default parameters.
    merge_requirements(reqs, extra_parameters)

    # Let's add our own universal declarations that let the caller customize
    # any query. (But allow subclass to redeclare for some flavors.)
    merge_requirements(reqs,
      :join?   => [:string],
      :tables? => [:string],
      :where?  => [:string],
      :group?  => :string,
      :order?  => :string,
      :by?     => :string
    )

    # Validate all expected parameters one at a time.
    for arg, type in reqs
      # Allow some parameters to be optional (not used yet).
      arg = arg.to_s
      question = !!arg.sub!(/\?$/,'')

      # Allow parameter names to be either symbols or strings.
      arg_sym = arg.to_sym
      val = old_args[arg] || old_args[arg_sym]
      old_args.delete(arg)
      old_args.delete(arg_sym)

      # Validate value if given.
      if val
        if type.is_a?(Array)
          val = array_validate(arg, val, type.first)
        else
          val = scalar_validate(arg, val, type)
        end
      end

      # Place validated value in final array, complaining if missing.
      if val
        new_args[arg_sym] = val
      elsif !question
        raise("Missing :#{arg} parameter for #{model} :#{flavor} query.")
      end
    end

    # Make sure there aren't any extra, unexpected arguments.
    if !old_args.keys.empty?
      str = old_args.keys.map(&:to_s).join("', '")
      raise("Unexpected parameter(s) '#{str}' for #{model} :#{flavor} query.")
    end

    self.params = new_args
  end

  # Merge the given "default" requirements into the list we have.
  def merge_requirements(reqs, extras)
    for key, val in extras || {}
      key1 = key.to_s.sub(/\?$/,'').to_sym
      key2 = "#{key1}?".to_sym
      if !reqs.has_key?(key1) &&
         !reqs.has_key?(key2)
        reqs[key] = val
      end
    end
  end

  # Validate an Array of values.
  def array_validate(arg, val, type)
    if val.is_a?(Array)
      val[0,MAX_ARRAY].map do |val2|
        scalar_validate(arg, val2, type)
      end
    else
      [scalar_validate(arg, val, type)]
    end
  end

  # Validate a single value.
  def scalar_validate(arg, val, type)

    # Scalar: Simple type-declaration.
    if type.is_a?(Symbol)
      send("validate_#{type}", arg, val)
    elsif type.is_a?(Class) and
          type.respond_to?(:descends_from_active_record?)
      validate_id(arg, val, type)

    # Hash: Type declaration with limit.
    elsif type.is_a?(Hash)
      if type.keys.length != 1
        raise("Invalid limit declaration for :#{arg} for #{model} :#{flavor} query! (wrong number of keys in hash)")
      end
      type2 = type.keys.first
      limit = type.values.first
      if !limit.is_a?(Array)
        raise("Invalid limit declaration for :#{arg} for #{model} :#{flavor} query! (expected value to be an array of allowed values)")
      end
      val2 = scalar_validate(arg, val, type2)
      if (type2 == :string) and
         limit.include?(val2.to_sym)
        val2 = val2.to_sym
      elsif !limit.include?(val2)
        raise("Value for :#{arg} should be one of the following: #{limit.inspect}.")
      end
      val2

    else
      raise("Invalid declaration of :#{arg} for #{model} :#{flavor} query! (invalid type: #{type.class.name})")
    end
  end

  # Make sure value is a boolean.
  def validate_boolean(arg, val)
    case val
    when :true, :yes, :on, 'true', 'yes', 'on', '1', 1, true
      true
    when :false, :no, :off, 'false', 'no', 'off', '0', 0, false, nil
      false
    else
      raise("Value for :#{arg} should be boolean, got: #{val.inspect}")
    end
  end

  # Make sure value is an integer.
  def validate_integer(arg, val)
    if val.is_a?(Fixnum) or
       val.is_a?(String) and val.match(/^-?\d+$/)
      val.to_i
    else
      raise("Value for :#{arg} should be an integer, got: #{val.inspect}")
    end
  end

  # Make sure value is a float.
  def validate_float(arg, val)
    if val.is_a?(Fixnum) or
       val.is_a?(Float) or
       val.is_a?(String) and val.match(/^-?\d+$/)
      val.to_f
    else
      raise("Value for :#{arg} should be a float, got: #{val.inspect}")
    end
  end

  # Make sure value is a string/symbol.
  def validate_string(arg, val)
    if val.is_a?(Fixnum) or
       val.is_a?(Float) or
       val.is_a?(String) or
       val.is_a?(Symbol)
      val.to_s
    else
      raise("Value for :#{arg} should be a string or symbol, got: #{val.inspect}")
    end
  end

  # Make sure value is an ActiveRecord instance or id.
  def validate_id(arg, val, type=ActiveRecord::Base)
    if val.is_a?(type)
      if !val.id
        raise("Value for :#{arg} is an unsaved #{type} instance.")
      end
      # Cache the instance for later use, in case we both instantiate and
      # execute query in the same action.
      @params_cache ||= {}
      @params_cache[arg] = val
      val.id
    elsif val.is_a?(Fixnum) or
          val.is_a?(String) && val.match(/^[1-9]\d*$/)
      val.to_i
    else
      raise("Value for :#{arg} should be id or an #{type} instance, got: #{val.inspect}")
    end
  end

  # Check if we already have an instance corresponding to this parameter,
  # otherwise look it up via ActiveRecord.
  def find_cached_parameter_instance(model, arg)
    @params_cache ||= {}
    @params_cache[arg] ||= model.find(params[arg])
  end

  ##############################################################################
  #
  #  :section: Building Queries
  #
  ##############################################################################

  # Has the SQL query been initialized?
  def initialized?
    !!@initialized
  end

  # Initialize the SQL query.  (This is called automatically by any methods
  # that require it, e.g. +query+, +results+, +select_values+.)
  def initialize_query
    @initialized = true
    table = model.table_name

    # By default, no conditions, ordering, etc.
    self.join   = []
    self.tables = []
    self.where  = []
    self.group  = ''
    self.order  = ''

    # Setup query for the given flavor.
    send("initialize_#{flavor}")

    # Give all queries the ability to order via simple :by => :name mechanism.
    superclass_initialize_order

    # Give subclass opportunity to make extra initializations before the final
    # customization / overriding below.
    extra_initialization

    # Give all queries ability to override / customize.
    self.join   += params[:join]   if params[:join]
    self.tables += params[:tables] if params[:tables]
    self.where  += params[:where]  if params[:where]
    self.group   = params[:group]  if params[:group]
    self.order   = params[:order]  if params[:order]
  end

  # Do mechanics of the :by => :type sorting mechanism.
  def superclass_initialize_order
    table = model.table_name

    by = params[:by]
    if by || order.to_s == ''
      by ||= default_order

      # Allow any of these to be reversed.
      reverse = !!by.sub!(/^reverse_/, '')

      # Let subclass decide how to order things.
      result = initialize_order(by)

      # Then provide some simple defaults.
      result ||= case by
      when 'modified', 'created', 'date'
        if model.column_names.include?(by)
          "#{table}.#{by} DESC"
        end
      when 'name', 'title', 'login'
        if model.column_names.include?(by)
          "#{table}.#{by} ASC"
        end
      when 'id' # (for testing)
        "#{table}.id ASC"
      end

      if result
        self.order = reverse ? reverse_order(result) : result
      else
        raise("Can't figure out how to sort #{model_string} by :#{by}.")
      end
    end
  end

  # Simple default query without filter.
  def initialize_all; end

  # Create fake query given the results.
  def initialize_in_set(ids=params[:ids])
    table = model.table_name
    set = clean_id_set(ids)
    self.where << "#{table}.id IN (#{set})"
    self.order = "FIND_IN_SET(#{table}.id,'#{set}') ASC"

    # Hey, check it out, we can populate the results cache immediately!
    @result_ids = ids
  end

  ##############################################################################
  #
  #  :section: Initialization Helpers
  #
  ##############################################################################

  # Put together a list of ids for use in a "id IN (1,2,...)" condition.
  #
  #   set = clean_id_set(name.children)
  #   self.where << "names.id IN (#{set})"
  #
  def clean_id_set(ids)
    result = ids.map(&:to_i).uniq[0,MAX_ARRAY].map(&:to_s).join(',')
    result = '0' if result == ''
    return result
  end

  # Clean a pattern for use in LIKE condition.  Takes and returns a String.
  def clean_pattern(pattern)
    pattern.gsub(/[%'"\\]/) {|x| '\\' + x}.gsub('*', '%')
  end

  # Combine args into single parenthesized condition by anding them together.
  def and_clause(*args)
    if args.length > 1
      '(' + args.join(' AND ') + ')'
    else
      args.first
    end
  end

  # Combine args into single parenthesized condition by oring them together.
  def or_clause(*args)
    if args.length > 1
      '(' + args.join(' OR ') + ')'
    else
      args.first
    end
  end

  # Give search string for notes google-like syntax:
  #   word1 word2     -->  any has both word1 and word2
  #   word1 OR word2  -->  any has either word1 or word2
  #   "word1 word2"   -->  any has word1 followed immediately by word2
  #   -word1          -->  none has word1
  #
  # Note, to conform to google, "OR" must be greedy, thus:
  #   word1 word2 OR word3 word4
  # is interpreted as:
  #   any has (word1 and (either word2 or word3) and word4)
  #
  # Note, the following are not allowed:
  #   -word1 OR word2
  #   -word1 OR -word2
  #
  # The result is an Array of positive asserions and an Array of negative
  # assertions.  Each positive assertion is one or more strings.  One of the
  # fields being searched must contain at least one of these strings out of
  # each assertion.  (Different fields may be used for different assertions.)
  # Each negative assertion is a single string.  None of the fields being
  # searched may contain any of the negative assertions.
  #
  #   search = google_parse(search_string)
  #   search.goods = [
  #     [ "str1", "or str2", ... ],
  #     [ "str3", "or str3", ... ],
  #     ...
  #   ]
  #   search.bads = [ "str1", "str2", ... ]
  #
  # Example result for "agaricus OR amanita -amanitarita":
  #
  #   search.goods = [ [ "agaricus", "amanita" ] ]
  #   search.bads  = [ "amanitarita" ]
  #
  def google_parse(str)
    goods = []
    bads  = []
    if (str = str.to_s.strip) != ''
      str.gsub!(/\s+/, ' ')
      # Pull off "and" clauses one at a time from the beginning of the string.
      while true
        if str.sub!(/^-"([^""]+)"( |$)/, '') or
           str.sub!(/^-(\S+)( |$)/, '')
          bads << $1
        elsif str.sub!(/^(("[^""]+"|\S+)( OR ("[^""]+"|\S+))*)( |$)/, '')
          str2 = $1
          or_strs = []
          while str2.sub!(/^"([^""]+)"( OR |$)/, '') or
                str2.sub!(/^(\S+)( OR |$)/, '')
            or_strs << $1
          end
          goods << or_strs
        else
          raise("Invalid search string syntax at: '#{str}'") if str != ''
          break
        end
      end
    end
    GoogleSearch.new(
      :goods => goods,
      :bads  => bads
    )
  end

  # Execute google-style search.  Pass in the GoogleSearch from +google_parse+,
  # an Array of fields to search, and any other query parameters, such as
  # +join+ table(s) or extra +where+ condition(s).  It returns a list of ids.
  def google_execute(search, args={})
    fields = args[:fields]
    args[:where] ||= []
    args[:where] = [args[:where]] if args[:where].is_a?(String)

    # Easiest case, only searching one field.
    if fields.length == 1
      args[:where] << google_conditions(search, fields.first)
      select_values(args).map(&:to_i)
  
    else
      # If searching multiple fields, concat them all together into one string.
      concat = 'CONCAT(' + fields.map do |field|
        "IF(#{field} IS NULL,'',#{field})"
      end.join(',') + ')'
  
      # Intermediate case, searching multiple fields, but only one condition.
      if search.goods.flatten.length + search.bads.length <= 1
        args[:where] << google_conditions(search, concat)
        select_values(args).map(&:to_i)

      # General case, searching multiple fields with multiple conditions.
      # Create a subquery that concats all the search fields together, then
      # apply all our conditions to that monster string.
      else
        args[:select] = "#{model.table_name}.id AS id, #{concat} AS str"
        subquery = query(args)
        model.connection.select_values(%(
          SELECT DISTINCT tmp.id FROM (#{subquery}) AS tmp
          WHERE #{google_conditions(search, 'tmp.str')}
        )).map(&:to_i)
      end
    end
  end

  # Put together a bunch of SQL conditions that describe a given search.
  def google_conditions(search, field)
    goods = search.goods
    bads  = search.bads
    ands = []
    ands += goods.map do |good|
      or_clause(*good.map {|str| "#{field} LIKE '%#{clean_pattern(str)}%'"})
    end
    ands += bads.map {|bad| "#{field} NOT LIKE '%#{clean_pattern(bad)}%'"}
    ands.join(' AND ')
  end

  # Simple class to hold the results of +google_parse+.  It just has two
  # attributes, +goods+ and +bads+.
  class GoogleSearch
    attr_accessor :goods, :bads
    def initialize(args={})
      self.goods = args[:goods]
      self.bads = args[:bads]
    end
  end

  ##############################################################################
  #
  #  :section: Build SQL Query
  #
  ##############################################################################

  # Build query for <tt>model.find_by_sql</tt> -- i.e. one that returns all
  # fields from the table in question, instead just the id.
  def query_all(args={})
    query(args.merge(:select => "DISTINCT #{model.table_name}.*"))
  end

  # Build query, allowing the caller to override/augment the standard
  # parameters.
  def query(args={})
    initialize_query if !initialized?

    our_select  = args[:select] || "DISTINCT #{model.table_name}.id"
    our_join    = self.join.dup
    our_join   += args[:join] if args[:join].is_a?(Array)
    our_join   << args[:join] if args[:join].is_a?(Hash)
    our_join   << args[:join] if args[:join].is_a?(Symbol)
    our_tables  = self.tables.dup
    our_tables += args[:tables] if args[:tables].is_a?(Array)
    our_tables << args[:tables] if args[:tables].is_a?(Symbol)
    our_from    = calc_from_clause(our_join, our_tables)
    our_where   = self.where.dup
    our_where  += args[:where] if args[:where].is_a?(Array)
    our_where  << args[:where] if args[:where].is_a?(String)
    our_where  += calc_join_conditions(model.table_name, our_join)
    our_where   = calc_where_clause(our_where)
    our_group   = args[:group] || self.group
    our_order   = args[:order] || self.order
    our_order   = reverse_order(self.order) if our_order == :reverse
    our_limit   = args[:limit]

    # Tack id at end of order to disambiguate the order.
    # (I despise programs that render random results!)
    if (our_order.to_s != '') and
       !our_order.match(/.id( |$)/)
      our_order += ", #{model.table_name}.id DESC"
    end

    sql = %(
      SELECT #{our_select}
      FROM #{our_from}
    )
    sql += "  WHERE #{our_where}\n"    if our_where.to_s != ''
    sql += "  GROUP BY #{our_group}\n" if our_group.to_s != ''
    sql += "  ORDER BY #{our_order}\n" if our_order.to_s != ''
    sql += "  LIMIT #{our_limit}\n"    if our_limit.to_s != ''

    return sql
  end

  # Format list of conditions for WHERE clause.
  def calc_where_clause(our_where=where)
    ands = our_where.uniq.map do |x|
      # Make half-assed attempt to cut down on proliferating parens...
      if x.match(/^\(.*\)$/) or !x.match(/ or /i)
        x
      else
        '(' + x + ')'
      end
    end
    ands.join(' AND ')
  end

  # Extract and format list of tables names from join tree for FROM clause.
  def calc_from_clause(our_join=join, our_tables=tables)
    tables = table_list(our_join, our_tables).
      sort_by {|x| table_order.index(x.to_s.to_sym) or raise("Don't know the table '#{x}'.")}.
      map {|x| "`#{x}`"}.
      join(', ')
  end

  # Extract a complete list of tables being used by this query.  (Combines
  # this table (+model.table_name+) with tables from +join+ with custom-joined
  # tables from +tables+.)
  def table_list(our_join=join, our_tables=tables)
    flatten_join([model.table_name] + our_join + our_tables).uniq
  end

  # Flatten join "tree" into a simple Array of Strings.
  def flatten_join(arg)
    result = []
    if arg.is_a?(Hash)
      for key, val in arg
        result << key.to_s.sub(/\..*/, '')
        result += flatten_join(val)
      end
    elsif arg.is_a?(Array)
      result += arg.map {|x| flatten_join(x)}.flatten
    else
      result << arg.to_s.sub(/\..*/, '')
    end
    return result
  end

  # Figure out which additional conditions we need to connect all the joined
  # tables.  Note, +to+ can be an Array and/or tree-like Hash of dependencies.
  # (I believe it is identical to how :include is done in ActiveRecord#find.)
  def calc_join_conditions(from, to)
    result = []
    from = from.to_s
    if to.is_a?(Hash)
      for key, val in to
        result += calc_join_condition(from, key.to_s)
        result += calc_join_conditions(key.to_s, val)
      end
    elsif to.is_a?(Array)
      result += to.map {|x| calc_join_conditions(from, x)}.flatten
    else
      result += calc_join_condition(from, to.to_s)
    end
    return result
  end

  # Create SQL condition to join two tables.
  def calc_join_condition(from, to)
    # Check for direct join first, e.g., if joining from observatons to
    # rss_logs, use "observations.rss_log_id = rss_logs.id".
    if col = (join_conditions[from.to_sym] && join_conditions[from.to_sym][to.to_sym])
      to = to.sub(/\..*/, '')
    # Now look for reverse join.  (In the above example, and this was how it
    # used to be, it would be "observations.id = rss_logs.observation_id".)
    elsif col = (join_conditions[to.to_sym] && join_conditions[to.to_sym][from.to_sym])
      to = to.sub(/\..*/, '')
      from, to = to, from
    else
      raise("Don't know how to join from #{from} to #{to}.")
    end
    if col == :obj || col == :object
      ["#{from}.#{col}_id = #{to}.id",
       "#{from}.#{col}_type = '#{to.singularize.camelize}'"]
    else
      ["#{from}.#{col} = #{to}.id"]
    end
  end

  # Reverse order of an ORDER BY clause.
  def reverse_order(order)
    order.gsub(/(\s)(ASC|DESC)(,|\Z)/) do
      $1 + ($2 == 'ASC' ? 'DESC' : 'ASC') + $3
    end
  end

  ##############################################################################
  #
  #  :section: Low-Level Queries
  #
  ##############################################################################

  # Execute query after wrapping select clause in COUNT().
  def select_count(args={})
    select = args[:select] || "DISTINCT #{model.table_name}.id"
    args = args.merge(:select => "COUNT(#{select})")
    model.connection.select_value(query(args)).to_i
  end

  # Call model.connection.select_value.
  def select_value(args={})
    model.connection.select_value(query(args))
  end

  # Call model.connection.select_values.
  def select_values(args={})
    model.connection.select_values(query(args))
  end

  # Call model.connection.select_rows.
  def select_rows(args={})
    model.connection.select_rows(query(args))
  end

  # Call model.connection.select_one.
  def select_one(args={})
    model.connection.select_one(query(args))
  end

  # Call model.connection.select_all.
  def select_all(args={})
    model.connection.select_all(query(args))
  end

  # Call model.find_by_sql.
  def find_by_sql(args={})
    model.find_by_sql(query_all(args))
  end

  ##############################################################################
  #
  #  :section: High-Level Queries
  #
  ##############################################################################

  # Return an Array of tables used in this query (Symbol's).
  def tables_used
    initialize_query if !initialized?
    table_list.map(&:to_s).sort.map(&:to_sym)
  end

  # Does this query use a given table?  (Takes String or Symbol.)
  def uses_table?(table)
    initialize_query if !initialized?
    table_list.map(&:to_s).include?(table.to_s)
  end

  # Number of results the query returns.
  def num_results
    result_ids.length
  end

  # Array of all results, just ids.
  def result_ids
    @result_ids ||= select_values.map(&:to_i)
  end

  # Array of all results, instantiated.
  def results(*args)
    instantiate(result_ids, *args)
  end

  # Let caller supply results if they happen to have them.  *NOTE*: These had
  # better all be valid instances of +model+ -- no error checking is done!!
  def results=(list)
    @result_ids = list.map(&:id)
    @results = list.inject({}) do |map,obj|
      map[obj.id] ||= obj
      map
    end
    return list
  end

  # Let caller supply results if they happen to have them.  *NOTE*: These had
  # better all be valid Fixnum ids -- no error checking is done!!
  def result_ids=(list)
    @result_ids = list
  end

  # Get index of a given record / id in the results.
  def index(arg)
    if arg.is_a?(ActiveRecord::Base)
      result_ids.index(arg.id)
    else
      result_ids.index(arg.to_s.to_i)
    end
  end

  # Returns a subset of the results (as ids).  Optional arguments:
  # +letter_field+:: Field in query to use for pagination-by-letter.  Pulls
  #                  the first letter from this field, even if not a letter!
  def paginate_ids(paginator, args={})
    expect_args(:paginate_ids, args, :letter_field)

    # Get list of letters used in results.
    if letter_field = args[:letter_field]
      paginator.used_letters = select_values(:select => "DISTINCT LEFT(#{letter_field},1)")
    end

    # Filter by letter.
    if letter = paginator.letter
      self.where << "LEFT(#{letter_field},1) = '#{letter}'"
      @result_ids = nil
    end

    # Paginate remaining results.
    paginator.num_total = num_results
    from, to = paginator.from, paginator.to
    result_ids[from..to] || []
  end

  # Returns a subset of the results (as ActiveRecord instances).
  def paginate(paginator, args={})
    args1, args2 = split_args(args, :letter_field)
    instantiate(paginate_ids(paginator, args1), args2)
  end

  # Instantiate a set of records given as an Array of ids.  Returns a list of
  # ActiveRecord instances in the same order as given.  Optional arguments:
  # +include+:: Tables to eager load (see argument of same name in
  #             ActiveRecord::Base#find for syntax).
  def instantiate(ids, args={})
    expect_args(:instantiate, args, :include)
    @results ||= {}
    ids.map!(&:to_i)
    needed = (ids - @results.keys).uniq
    if !needed.empty?
      set = clean_id_set(needed)
      args2 = {}
      args2[:conditions] = "#{model.table_name}.id IN (#{set})"
      args2[:include] = args[:include] if args[:include]
      model.all(args2).each do |obj|
        @results[obj.id] = obj
      end
    end
    ids.map {|id| @results[id]}
  end

  # Clear out the results cache.  Useful if you need to reload results with
  # more eager loading, or if you need to repaginate something with letters.
  def clear_cache
    @results = nil
    @result_ids = nil
  end

  ##############################################################################
  #
  #  :section: Sequence Operators
  #
  ##############################################################################

  # Return current place in results, as an id.  (Returns nil if not set yet.)
  def this_id
    @this_id
  end

  # Set current place in results; takes id (String or Fixnum).
  def this_id=(id)
    @save_this_id = @this_id = id.to_s.to_i
  end

  # Reset current place in results to the place last given in a "this=" call.
  def reset
    @this_id = @save_this_id
  end

  # Return current place in results, instantiated.  (Returns nil if not set
  # yet.)
  def this(*args)
    @this_id ? instantiate([@this_id], *args).first : nil
  end

  # Set current place in results; takes instance or id (String or Fixnum).
  def this=(arg)
    if arg.is_a?(model)
      @results ||= {}
      @results[arg.id] = arg
      self.this_id = arg.id
    else
      self.this_id = arg
    end
    return arg
  end

  # Move to first place.
  def first(skip_outer=false)
    new_self = self
    new_self = outer_first if !skip_outer && has_outer?
    id = new_self.select_value(:limit => '1').to_i
    if id > 0
      if new_self == self
        @this_id = id
      else
        new_self.this_id = id
      end
    else
      new_self = nil
    end
    return new_self
  end

  # Move to previous place.
  def prev
    new_self = self
    ids = result_ids
    index = result_ids.index(this_id)
    if !index
      new_self = nil
    elsif index > 0
      if new_self == self
        @this_id = result_ids[index - 1]
      else
        new_self.this_id = result_ids[index - 1]
      end
    elsif has_outer?
      while new_self = new_self.outer_prev
        if new_new_self = new_self.last(:skip_outer)
          new_self = new_new_self
          break
        end
      end
    else
      new_self = nil
    end
    return new_self
  end

  # Move to next place.
  def next
    new_self = self
    ids = result_ids
    index = result_ids.index(this_id)
    if !index
      new_self = nil
    elsif index < result_ids.length - 1
      if new_self == self
        @this_id = result_ids[index + 1]
      else
        new_self.this_id = result_ids[index + 1]
      end
    elsif has_outer?
      while new_self = new_self.outer_next
        if new_new_self = new_self.first(:skip_outer)
          new_self = new_new_self
          break
        end
      end
    else
      new_self = nil
    end
    return new_self
  end

  # Move to last place.
  def last(skip_outer=false)
    new_self = self
    new_self = outer_last if !skip_outer && has_outer?
    id = new_self.select_value(:order => :reverse, :limit => '1').to_i
    if id > 0
      if new_self == self
        @this_id = id
      else
        new_self.this_id = id
      end
    else
      new_self = nil
    end
    return new_self
  end

  ##############################################################################
  #
  #  :section: Nested Queries
  #
  ##############################################################################

  # Is this query nested in an outer query?
  def has_outer?
    !outer_id.nil?
  end

  # Get instance for +outer_id+, modifying it slightly to skip results with
  # empty inner queries.
  def outer
    @outer ||= begin
      if outer_id
        outer = self.class.find(outer_id)
        if tweak_outer_query
          tweak_outer_query.call(outer)
        end
        outer
      else
        nil
      end
    end
  end

  # Each inner query corresponds to a single result of the outer query.  This
  # method is called on the inner query, returning the +this_id+ of the outer
  # query for that result.
  def get_outer_this_id
    if outer_this_id
      outer_this_id.call(self)
    else
      params[outer.model_string.underscore.to_sym]
    end
  end

  # Create a new copy of this query corresponding to the new outer query.
  def new_inner(new_outer)
    new_params = params.merge(:outer => new_outer.id)
    if setup_new_inner_query
      setup_new_inner_query.call(new_params, new_outer)
    else
      new_params[new_outer.model_string.underscore.to_sym] = new_outer.this_id
    end
    self.class.lookup_and_save(model, flavor, new_params)
  end

  # Create a new copy of this query if the outer query changed, otherwise
  # returns itself unchanged.
  def new_inner_if_necessary(new_outer)
    if !new_outer
      nil
    elsif new_outer.this_id == get_outer_this_id
      self
    else
      new_inner(new_outer)
    end
  end

  # Move outer query to first place.
  def outer_first
    outer.this_id = get_outer_this_id
    new_inner_if_necessary(outer.first)
  end

  # Move outer query to previous place.
  def outer_prev
    outer.this_id = get_outer_this_id
    new_inner_if_necessary(outer.prev)
  end

  # Move outer query to next place.
  def outer_next
    outer.this_id = get_outer_this_id
    new_inner_if_necessary(outer.next)
  end

  # Move outer query to last place.
  def outer_last
    outer.this_id = get_outer_this_id
    new_inner_if_necessary(outer.last)
  end

  ##############################################################################
  #
  #  :stopdoc: Other Stuff
  #
  ##############################################################################

  # Raise an error if caller passed any unexpected arguments.
  def expect_args(method, args={}, *expect) # :nodoc:
    extra_args = args.keys - expect
    if !extra_args.empty?
      raise "Unexpected arguments to Query##{method}: #{extra_args.inspect}"
    end
  end

  # Split up a Hash of arguments, putting all the ones in the given list in
  # the first of two Hash's, and all the rest in the other.  Returns two Hash's.
  def split_args(args={}, *keys_in_first) # :nodoc:
    args1 = {}
    args2 = {}
    args.each do |key, val|
      if keys_in_first.include?(key)
        args1[key] = val
      else
        args2[key] = val
      end
    end
    return [args1, args2]
  end
end

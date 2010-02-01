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
#    query.include << :names
#    query.where   << 'names.correct_spelling_id IS NULL'
#    query.order   =  'names.search_name ASC'
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
#    @names = query.paginate(@pages, 'names.search_name')
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
#  include::            Tree of tables used in query.
#  where::              List of WHERE clauses in query.
#  order::              ORDER clause in query.
#
#  == Class Methods
#  lookup::             Lookup a Query, creating it if necessary (unsaved)
#  lookup_and_save::    Same, but save it, too.
#  cleanup::            Do garbage collection on old or unused Query's.
#
#  ==Instance Methods
#  coerce::             Coerce a query for one model into a query for another.
#  clone::              Clone an instance for tweaking.
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
#  num_results::        Number of results the query returns.
#  results::            Array of all results, instantiated.
#  result_ids::         Array of all results, just ids.
#  paginate::           Array of subset of results, instantiated.
#  paginate_ids::       Array of subset of results, just ids.
#
#  ==== Outer queries
#  outer::              Outer Query (if nested).
#  has_outer?::         Is this Query nested?
#  outer_this_id::      Outer Query's current id.
#  outer_first::        Call +first+ on outer Query.
#  outer_prev::         Call +prev+ on outer Query.
#  outer_next::         Call +next+ on outer Query.
#  outer_last::         Call +last+ on outer Query.
#  new_inner::          Create new inner Query based the given outer Query.
#  new_inner_if_necessary::
#                       Create new inner Query if the outer Query has changed.
#
#  == Instance Variables
#
#  @initialized::       Boolean: has +initialize_query+ been called yet?
#  @model_class::       Class: associated model.
#  @this::              Instance of +@model_class+: current place in results.
#  @save_this::         Saved copy of @this for +reset+.
#  @results::           Array of instances of +@model_class+: all results.
#  @result_ids::        Array of Fixnum: all results (ids).
#  @num_results::       Fixnum: total number of results available.
#
################################################################################

class AbstractQuery < ActiveRecord::Base
  self.abstract_class = true

  # Parameters are kept in a Hash, possibly with Arrays as values.
  serialize :params, Hash

  # This is where +data+ is extracted to.
  attr_accessor :include, :where, :order

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

  # Override this method in your subcass.
  def initialize_extra; end

  # Override this method in your subcass.
  def default_order; 'id'; end

  # Override this method in your subcass.
  def initialize_order(by); nil; end

  # Overrider this method in your subcass.
  def outer_tweak(outer); end

  # Overrider this method in your subcass.
  def outer_this_id; raise("missing method"); end

  # Overrider this method in your subcass.
  def outer_setup(new_outer, new_params); raise("missing method"); end

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

  ############################################################################
  #
  #  :section: Construction
  #
  ############################################################################

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
    query.save
    query
  end

  # Create clone of this query (unsaved).
  def clone
    self.class.new(attributes)
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
    params = YAML::dump(query.params)
    if other = find_by_model_and_flavor_and_params(model, flavor, params)
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
      WHERE access_count = 0 AND modified < DATE_SUB(NOW(), INTERVAL 1 HOUR) OR
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
  # cases; returns +nil+ in all other cases.
  def coerce(new_model)
    result = nil
    new_model = new_model.to_s.to_sym

    # Trivial case -- model's not actually different!
    if model == new_model
      result = self
    end

    return result
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
      :include? => [:string],
      :where?   => [:string],
      :order?   => :string,
      :by?      => :string
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
      val.map do |val2|
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
      val.id
    elsif val.is_a?(Fixnum) or
          val.is_a?(String) && val.match(/^[1-9]\d*$/)
      val.to_i
    else
      raise("Value for :#{arg} should be id or an #{type} instance, got: #{val.inspect}")
    end
  end

  ##############################################################################
  #
  #  :section: Building Queries
  #
  ##############################################################################

  def initialize_query
    table = model.table_name

    # By default, no conditions, ordering, etc.
    self.include = []
    self.where   = []
    self.order   = ''

    # Setup query for the given flavor.
    send("initialize_#{flavor}")

    # Give all queries the ability to order via simple :by => :name mechanism.
    superclass_initialize_order

    # Give subclass opportunity to make extra initializations before the final
    # customization / overriding below.
    initialize_extra

    # Give all queries ability to override / customize.
    self.include += params[:include] if params[:include]
    self.where   += params[:where]   if params[:where]
    self.order    = params[:order]   if params[:order]
  end

  # Do mechanics of the :by => :type sorting mechanism.
  def superclass_initialize_order
    table = model.table_name

    by = params[:by]
    if by || order.to_s == ''
      by ||= default_order

      # Allow any of these to be reversed.
      reverse = !!by.sub!(/^reverse_$/, '')

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
  def initialize_in_set
    table = model.table_name
    set = params[:ids].map(&:to_s).join(',')
    set = 0 if set == ''
    self.where << "#{table}.id IN (#{set})"
    self.order << "FIND_IN_SET(#{table}.id,'#{set}') ASC"

    # Hey, check it out, we can populate the results cache immediately!
    @result_ids  = set.split(',').map(&:to_i)
    @num_results = @result_ids.length
  end

  # Give search string for notes google-like syntax:
  #   word1 word2     -->  has both word1 and word2
  #   word1 OR word2  -->  has either word1 or word2
  #   "word1 word2"   -->  has word1 followed immediately by word2
  #   -word1          -->  doesn't have word1
  # Note, to conform to google, "OR" must be greedy, thus:
  #   word1 word2 OR word3 word4
  # is interpreted as:
  #   has word1 and (either word2 or word3) and word4
  def full_google_search(pat, *fields)
    results = []
    if pat2 = pat
      and_pats = []
      while pat2.sub!(/^(-?("[^"]*"|[^ ]+)( OR -?("[^"]*"|[^ ]+))*) ?/, '')
        pat3 = $1
        or_pats = []
        while pat3.sub!(/^(-)?"([^"]*)"( OR )?/, '') or
              pat3.sub!(/^(-)?([^ ]+)( OR )?/, '')
          do_not = $1 == '-' ? 'NOT ' : ''
          pat4 = $2
          clean_pat = pat4.gsub(/[%'"\\]/) {|x| '\\' + x}.gsub('*', '%')
          or_pats += fields.map {|f| "#{f} #{do_not}LIKE '%#{clean_pat}%'"}
        end
        if or_pats.length > 1
          and_pats << '(' + or_pats.join(' or ') + ')'
        elsif or_pats.length > 0
          and_pats << or_pats.first
        end
      end
      if and_pats.length > 2
        results << '(' + and_pats.join(' and ') + ')'
      elsif and_pats.length > 0
        results << and_pats.first
      end
    end
  end

  # User name, location name, mushroom name, etc. are much simpler.
  #   aaa bbb             -->  name is "...aaa bbb..."
  #   aaa bbb OR ccc ddd  -->  name is either "...aaa bbb..." or "...ccc ddd..."
  def soft_google_search(pat, *fields)
    results = []
    if pat
      or_pats = []
      for pat2 in pat.split(' OR ')
        clean_pat = pat2.gsub(/[%'"\\]/) {|x| '\\' + x}.gsub('*', '%')
        or_pats += fields.map {|f| "#{f} LIKE '%#{clean_pat}%'"}
      end
      if or_pats.length > 1
        results << '(' + or_pats.join(' or ') + ')'
      elsif or_pats.length > 0
        results << or_pats.first
      end
    end
  end

  ############################################################################
  #
  #  :section: Build SQL Query
  #
  ############################################################################

  # Build query for <tt>model.find_by_sql</tt> -- i.e. one that returns all
  # fields from the table in question, instead just the id.
  def query_all(args={})
    query(args.merge(:select => "DISTINCT #{model.table_name}.*"))
  end

  # Build query, allowing the caller to override/augment the standard
  # parameters.
  def query(args={})
    initialize_query if !@initialized
    @initialized = true

    our_select   = args[:select] || "DISTINCT #{model.table_name}.id"
    our_include  = include
    our_include += args[:include] if args[:include]
    our_from     = calc_from_clause(our_include)
    our_where    = where
    our_where   += args[:where] if args[:where]
    our_where   += calc_join_conditions(our_include)
    our_where    = calc_where_clause(our_where)
    our_order    = args[:order] || order
    our_order    = reverse_order(order) if our_order == :reverse
    our_limit    = args[:limit]

    sql = %(
      SELECT #{our_select}
      FROM #{our_from}
    )
    sql += "  WHERE #{our_where}\n"    if our_where.to_s != ''
    sql += "  ORDER BY #{our_order}\n" if our_order.to_s != ''
    sql += "  LIMIT #{our_limit}\n"    if our_limit.to_s != ''

    return sql
  end

  # Format list of conditions for WHERE clause.
  def calc_where_clause(our_where=where)
    our_where.uniq.map {|x| "(#{x})"}.join(' AND ')
  end

  # Extract and format list of tables names from include tree for FROM clause.
  def calc_from_clause(our_include=include)
    flatten_include([model.table_name] + our_include).
      uniq.
      sort_by {|x| table_order.index(x.to_s.to_sym) or raise("Don't know the table '#{x}'.")}.
      map {|x| "`#{x}`"}.
      join(', ')
  end

  # Flatten include "tree" into a simple Array of Strings.
  def flatten_include(arg)
    result = []
    if arg.is_a?(Hash)
      for key, val in arg
        result << key.to_s.sub(/\..*/, '')
        result += flatten_include(val)
      end
    elsif arg.is_a?(Array)
      result += arg.map {|x| flatten_include(x)}.flatten
    else
      result << arg.to_s.sub(/\..*/, '')
    end
    return result
  end

  # Figure out which additional conditions we need to connect all the joined
  # tables.
  def calc_join_conditions(arg=include, from=model.table_name)
    result = []
    if arg.is_a?(Hash)
      for key, val in arg
        result += calc_join_condition(from, key.to_s)
        result += calc_join_conditions(val, key.to_s)
      end
    elsif arg.is_a?(Array)
      result += arg.map {|x| calc_join_conditions(x, from)}.flatten
    else
      result += calc_join_condition(from, arg.to_s)
    end
    return result
  end

  # Create SQL condition to join two tables.
  def calc_join_condition(from, to)
    if col = (join_conditions[from.to_sym] && join_conditions[from.to_sym][to.to_sym])
      to = to.sub(/\..*/, '')
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

  ################################################################################
  #
  #  :section: Execute Queries
  #
  ################################################################################

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

  # Number of results the query returns.
  def num_results
    @num_results ||= select_count
  end

  # Array of all results, instantiated.
  def results
    @results ||= find_by_sql
    @num_results = @results.length
    return @results
  end

  # Array of all results, just ids.
  def result_ids
    if !@result_ids
      if @results
        @result_ids = @results.map(&:id)
      else
        @result_ids = select_values(query).map(&:to_i)
        @num_results = @result_ids.length
      end
    end
    return @result_ids
  end

  # Let caller supply results if they happen to have them.  *NOTE*: These had
  # better all be valid instances of +model+ -- no error checking is done!!
  def results=(list)
    @num_results = list.length
    @results = list
  end

  # Let caller supply results if they happen to have them.  *NOTE*: These had
  # better all be valid integer ids -- no error checking is done!!
  def result_ids=(list)
    @num_results = list.length
    @result_ids = list
  end

  # Returns a subset of the results.
  def paginate(paginator, letter_field=nil)

    # Filter by letter, then paginate.
    if letter = paginator.letter
      letter_conditions = ["#{letter_field} LIKE '#{letter}%'"]
      from, to = paginator.from, paginator.to
      paginator.num_total = select_count(:where => letter_conditions)
      find_by_sql(:where => letter_conditions, :limit => "#{from}, #{to}")

    # Normal pagination.
    else
      paginator.num_total = num_results
      from, to = paginator.from, paginator.to
      if @results
        @results[from..to]
      elsif @result_ids
        ids = @result_ids[from..to]
        map = model.all(:conditions => ['id IN (?)', ids]).
              inject({}) {|map,obj| map[obj.id] = obj; map}
        @result_ids.map {|id| map[id]}
      else
        find_by_sql(:limit => "#{from}, #{to}")
      end
    end
  end

  # Returns a subset of the results.
  def paginate_ids(paginator, letter_field=nil)

    # Filter by letter, then paginate.
    if letter = paginator.letter
      letter_conditions = ["#{letter_field} LIKE '#{letter}%'"]
      paginator.num_total = select_count(:where => letter_conditions)
      from, to = paginator.from, paginator.to
      select_values(:where => letter_conditions, :limit => "#{from}, #{to}").map(&:to_i)

    # Normal pagination.
    else
      paginator.num_total = num_results
      from, to = paginator.from, paginator.to
      if @results
        @results[from..to].map(&:id)
      elsif @result_ids
        @result_ids[from..to]
      else
        select_values(:limit => "#{from}, #{to}").map(&:to_i)
      end
    end
  end

  ############################################################################
  #
  #  :section: Sequence Operators
  #
  ############################################################################

  # Set current place in results; takes instance or id (String or Fixnum).
  def this=(arg)
    if arg.is_a?(model)
      @this = arg
    elsif arg.is_a?(Fiargnum)
      @this = model.find(arg)
    elsif arg.is_a?(String) and
          (arg.to_i > 0 rescue false)
      @this = model.find(arg)
    else
      raise("Invalid argument: '#{arg.class}: #{arg}'")
    end
    @save_this = @this
  end

  # Set current place in results; takes id (String or Fixnum).
  def this_id=(id)
    @save_this = @this = model.find(id)
  end

  # Return current place in results, instantiated.
  def this
    @this
  end

  # Return current place in results, as an id.  (Returns nil if not set yet.)
  def this_id
    @this && @this.id
  end

  # Reset current place in results to the place last given in a "this=" call.
  def reset
    @this = @save_this
  end

  # Move to first place.
  def first(skip_outer=false)
    new_self = self
    new_self = outer_first if !skip_outer && has_outer?
    id = select_value(:limit => '1').to_i
    if id > 0
      new_self.this_id = id
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
      new_self.this_id = result_ids[index - 1]
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
      new_self.this_id = result_ids[index + 1]
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
      new_self.this_id = id
    else
      new_self = nil
    end
    return new_self
  end

  ############################################################################
  #
  #  :section: Outer Queries
  #
  ############################################################################

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
        outer_tweak(outer)
        outer
      else
        nil
      end
    end
  end

  # Create a new copy of this query corresponding to the new outer query.
  def new_inner(new_outer)
    new_params = params.merge(:outer => new_outer.id)
    outer_setup(new_outer, new_params)
    self.class.create(model, flavor, new_params)
  end

  # Create a new copy of this query if the outer query changed, otherwise
  # returns itself unchanged.
  def new_inner_if_necessary(new_outer)
    if !new_outer
      nil
    elsif new_outer.this_id == outer_this_id
      self
    else
      new_inner(new_outer)
    end
  end

  # Move outer query to first place.
  def outer_first
    outer.this_id = outer_this_id
    new_inner_if_necessary(outer.first)
  end

  # Move outer query to previous place.
  def outer_prev
    outer.this_id = outer_this_id
    new_inner_if_necessary(outer.prev)
  end

  # Move outer query to next place.
  def outer_next
    outer.this_id = outer_this_id
    new_inner_if_necessary(outer.next)
  end

  # Move outer query to last place.
  def outer_last
    outer.this_id = outer_this_id
    new_inner_if_necessary(outer.last)
  end
end

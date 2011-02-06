#
#  = Query Model
#
#  This model encapsulates a database query that looks up one or more objects
#  of a given type that match certain conditions in a certain order.  Queries
#  are dyamically joined with any number of additional tables, as required by
#  sorting and selection conditions.
#
#  Queries are specified by a model and flavor.  The model specifies which kind
#  of objects are being requested, e.g. :Name or :Observation.  The flavor
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
#  are somewhat more subtle than shown here, as nested queries may require the
#  creation of new query instances.  See the section on nested queries below.)
#
#    query = Query.lookup(:Observation)
#    query.current = @observation
#    next  = query.current if query.next
#    this  = query.current if query.prev
#    prev  = query.current if query.prev
#    first = query.current if query.first
#    last  = query.current if query.last
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
#    query.need_letters = 'names.search_name'
#    @pages = paginate_letters
#    @names = query.paginate(@pages)
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
#      puts "Next image is: " + new_query.current_id
#    else
#      puts "No more images."
#    end
#
#    # Must reset otherwise query.prev just goes back to original place.
#    query.reset
#    if new_query = query.prev
#      puts "Previous image is: " + new_query.current_id
#    else
#      puts "No more images."
#    end
#
#    # Note: query.last works the same.
#    if new_query = query.first
#      puts "First image is: " + new_query.current_id
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
#    query = find_or_create_query(:Image, :current => params[:id])
#    if new_query = query.next
#      redirect_to(:action => 'show_image', :id => new_query.current_id,
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
#  It caches results, and result_ids.  Any of results, result_ids, num_results,
#  or paginate populates result_ids, however results are only instantiated as
#  necessary.  (I found that requesting all the ids was not significantly
#  slower than requesting the count, while calling _both_ was nearly twice as
#  long as just one.  So, there was no reason to optimize the query if you only
#  want the number of results.)
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
#                       (*NOTE*: Use +replace_params+ instead if <tt>params=</tt>.)
#  user::               User that created.
#  user_id::            (same, as id)
#  modified::           Last time it was used.
#  access_count::       Number of times its been used.
#
#  ==== Local attributes
#  current::            Current location in query (for sequence operators).
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
#  uses_join?::         Does the query use this join clause?
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
#  get_outer_current_id::  Get outer Query's current id.
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
#  @@default_flavor_params:: Default required parameters declarations.
#
#  ==== Instance Variables
#  @params::            Hash:: cached copy of deserialized parameter hash.
#  @initialized::       Boolean: has +initialize_query+ been called yet?
#  @model_class::       Class: associated model.
#  @current_id::        Fixnum: current place in results.
#  @save_current_id::   Fixnum: saved copy of +@current_id+ for +reset+.
#  @result_ids::        Array of Fixnum: all results.
#  @results::           Hash: maps ids to instantiated records.
#  @letters::           Cache of first-letters (if +need_letters given).
#  @outer::             AbstractQuery: cached copy of outer query (nested
#                       queries only).
#  @params_cache::      Hash: where instances passed in via params are cached.
#
################################################################################

class AbstractQuery < ActiveRecord::Base
  self.abstract_class = true

  # Low-level description of SQL query.
  attr_accessor :join, :tables, :where, :group, :order, :executor

  # Will we need first-letters for pagination-by-letter later?  Value is the
  # field or SQL expression to use.  We can do some simple optimizations to
  # grab the pagination letter along with the ids the first time through if we
  # know that we will need them.
  attr_accessor :need_letters

  # Cached Hash mapping result ids (Fixnum) to first-letters (String).
  attr_accessor :letters

  # Save last query for debug / diagnostic purposes.
  attr_accessor :last_query

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
  #   self.flavor_params = {
  #     :by_user   => {:user => User}
  #     :with_name => {:name => Name, :optional_flag? => :boolean}
  #     :in_set    => {:ids => [:id]}
  #     :search    => {:pattern => :string, :mode? => {:string => [:simple, :complex]}}
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
  superclass_delegating_accessor :flavor_params
  self.flavor_params = {}
  @@default_flavor_params = {
    :ids => [:id],
  }

  # Add these to the list of required parameters for a given model (Symbol).
  #
  #   self.model_params = {
  #     :Name => { :misspellings => :boolean },
  #     :User => ...,
  #   }
  #
  superclass_delegating_accessor :model_params
  self.model_params = {}
  @@default_model_params = {}

  # Add these to the list of required parameters for all queries.
  #
  #   self.global_params = {
  #     :title? => :string,
  #     ...
  #   }
  #
  superclass_delegating_accessor :global_params
  self.global_params = {}
  @@default_global_params = {
    :join?   => [:string],
    :tables? => [:string],
    :where?  => [:string],
    :group?  => :string,
    :order?  => :string,
    :by?     => :string,
  }

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

  # This gives the subclass opportunity to make extra global initializations
  # *after* flavor- and model-specific initializations.  The following global
  # initializations cannot be overridden:
  #
  # +join+::   Joins to additional table(s).
  # +tables+:: Extra table(s) or subqueries.
  # +where+::  Adds extra condition(s) to WHERE condition.
  # +group+::  Adds GROUP BY clause.
  # +order+::  Overrides ORDER BY clause.
  # +by+::     Sort order (see +initialize_order+).
  #
  def initialize_global; end

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
  # lets the inner query tell the corresponding +current_id+ of the outer
  # query.  By default, it gets it from a parameter of the same name as the
  # outer's model (e.g., <tt>params[:user]</tt> for inner queries nested inside
  # :User queries).
  #
  # This instance variable is a Proc, initialized in the flavor-specific
  # initializer.  For example, the default would look like this:
  #
  #   def initialize_inside_user
  #     ...
  #     self.outer_current_id = lambda do |inner|
  #       inner.params[:user]
  #     end
  #   end
  #
  attr_accessor :outer_current_id

  # This tells us how to create a new inner query based on another result of
  # the same outer query.  This is called, for example, when using the sequence
  # operators on an inner query.  When it runs out of results for the inner
  # query, it goes to the next result in the outer query, and creates a new
  # inner query corresponding to it.  By default, it just stores the outer
  # result (<tt>outer.current_id</tt>) in a parameter with the same name as the
  # outer query's model (e.g., <tt>params[:user] = outer.current_id</tt> for inner
  # queries nested inside :User queries).
  #
  # This instance variable is a Proc, initialized in the flavor-specific
  # initializer.  For example, the default would look like this:
  #
  #   def initialize_inside_user
  #     ...
  #     self.setup_new_inner_query = lambda do |new_params, new_outer|
  #       new_params[:user] = new_outer.current_id
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

  ################################################################################
  #
  #  :section: Parameters
  #
  #  I tried to use 'serialize :params, Hash' on this, but YAML randomizes the
  #  order of the keys of hashes, so lookup was sometimes (randomly) failing.
  #
  #  This much-simplified serialization handles the standard scalars (String,
  #  Symbol, Fixnum, Float, true, false, nil) as well as nested Array's thereof.
  #
  ################################################################################

  # Deserialize params hash and cache it.
  def params
    @params ||= params_parse_hash(@attributes['params'])
  end

  # Replace parameters Hash with a new Hash.
  def replace_params(x)
    if !x.is_a?(Hash)
      raise "Params must be a Hash, not a '#{x.class.name}:#{x}'"
    end
    @params = x
  end

  # Serialize params hash before saving it.
  def before_save
    # No need to reserialize if we never parsed it to start with.
    if @params
      self.params = params_write_hash(@params)
    end
  end

  # Parse a Hash out of a String.
  def params_parse_hash(str)
    hash = {}
    str.to_s.split("\n").each do |line|
      if line.match(/^(\w+) (.*)/)
        hash[$1.to_sym] = params_parse_val($2)
      end
    end
    return hash
  end

  # Serialize a Hash.
  def params_write_hash(hash)
    hash.keys.sort_by(&:to_s).map do |key|
      if key.to_s.match(/\W/)
        raise "Keys of params must be all alphanumeric: '#{key}'"
      end
      "#{key} #{params_write_val(@params[key])}"
    end.join("\n")
  end

  # Parse a single value from a String.
  def params_parse_val(val)
    val.sub!(/^(.)/,'')
    case $1
    when '[' ; val.split.map {|v| params_parse_val(v)}
    when '"' ; val.gsub('%s',' ').gsub('%h','%').gsub('\\n',"\n")
    when ':' ; val.gsub('%s',' ').gsub('%h','%').gsub('\\n',"\n").to_sym
    when '#' ; val.to_i
    when '.' ; val.to_f
    when '1' ; true
    when '0' ; false
    when '-' ; nil
    else raise "Invalid value in params: '#{$1}#{val}'"
    end
  end

  # Write a single value to a String.
  def params_write_val(val)
    case val
    when Array      ; '[' + val.map {|v| params_write_val(v)}.join(" ")
    when String     ; '"' + val.to_s.gsub('%','%h').gsub(' ','%s').gsub("\n",'\\n')
    when Symbol     ; ':' + val.to_s.gsub('%','%h').gsub(' ','%s').gsub("\n",'\\n')
    when Fixnum     ; '#' + val.to_s
    when Float      ; '.' + val.to_s
    when TrueClass  ; '1'
    when FalseClass ; '0'
    when NilClass   ; '-'
    else raise "Invalid value in params: '#{val.class.name}:#{val.to_s}'"
    end
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
    if flavor == :default || flavor.blank?
      flavor = default_flavors[model.to_s.to_sym] || :all
    end

    # Make sure this is a recognized query type.
    model = model.to_s.to_sym
    if !allowed_model_flavors.has_key?(model)
      raise("Invalid model: '#{model}'")
    elsif !allowed_model_flavors[model].include?(flavor)
      raise("Invalid query for #{model} model: '#{flavor}'")
    end

    # Let caller combine lookup and current= in one call.
    if arg = params[:current] || params[:current_id]
      params.delete(:current)
      params.delete(:current_id)
      set_current = arg
    end

    # Initialize attributes, but don't create query or do anything yet.
    query.attributes = {
      :model        => model,
      :flavor       => flavor,
      :user         => User.current,
      :modified     => Time.now,
      :access_count => 0,
    }
    query.replace_params(params)

    # Make sure all required params exist and are valid; also make sure there
    # aren't any unexpected arguments.
    query.validate_params

    # See if such a query already exists and use it instead.
    str = query.params_write_hash(query.params)
    if other = find_by_model_and_flavor_and_params(model, flavor, str)
      query = other
    end

    # Okay to set "current" now.
    if set_current
      query.current = set_current
    end

    return query
  end

  # Instantiate (unsaved!) a dummy lookup without any parameters.
  def self.template(model, flavor)
    model  = model.to_s.to_sym
    flavor = flavor.to_s.to_sym

    # Make sure this is a recognized query type.
    if !allowed_model_flavors.has_key?(model)
      raise("Invalid model: '#{model}'")
    elsif !allowed_model_flavors[model].include?(flavor)
      raise("Invalid query for #{model} model: '#{flavor}'")
    end

    # Create minimal instance.
    query = new(
      :model  => model,
      :flavor => flavor
    )
    query.replace_params({})

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

    # Get the parameters declarations.
    reqs = parameter_declarations

    # Validate all expected parameters one at a time.
    for arg, type in reqs
      # Allow some parameters to be optional (not used yet).
      arg = arg.to_s
      question = !!arg.sub!(/\?$/,'')

      # Allow parameter names to be either symbols or strings.
      arg_sym = arg.to_sym
      val = old_args[arg]
      val = old_args[arg_sym] if val.nil?
      old_args.delete(arg)
      old_args.delete(arg_sym)

      # Validate value if given.
      if !val.nil?
        if type.is_a?(Array)
          val = array_validate(arg, val, type.first)
        else
          val = scalar_validate(arg, val, type)
        end
      end

      # Place validated value in final array, complaining if missing.
      if !val.nil?
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

    replace_params(new_args)
  end

  # Get the parameters declarations.
  def self.parameter_declarations(model_symbol, flavor)
    reqs = @@default_flavor_params[flavor] || {}
    merge_requirements(reqs, @@default_model_params[model_symbol] || {})
    merge_requirements(reqs, @@default_global_params || {})
    merge_requirements(reqs, flavor_params[flavor] || {})
    merge_requirements(reqs, model_params[model_symbol] || {})
    merge_requirements(reqs, global_params || {})
    return reqs
  end

  # Merge the given "default" requirements into the list we have.
  def self.merge_requirements(reqs, extras)
    for key, val in extras || {}
      key1 = key.to_s.sub(/\?$/,'').to_sym
      key2 = "#{key1}?".to_sym
      if !reqs.has_key?(key1) &&
         !reqs.has_key?(key2)
        reqs[key] = val
      end
    end
  end

  # Return a list of required parameters sorted by name (Symbol's).
  def self.required_parameters(model_symbol, flavor)
    result = []
    for key, val in parameter_declarations(model_symbol, flavor)
      result << key if !key.to_s.match(/\?$/)
    end
    return result.sort_by(&:to_s)
  end

  # Return a list of optional parameters sorted by name (Symbol's).
  def self.optional_parameters(model_symbol, flavor)
    result = []
    for key, val in parameter_declarations(model_symbol, flavor)
      result << $1.to_sym if key.to_s.match(/(.*)\?$/)
    end
    return result.sort_by(&:to_s)
  end

  # Return a list of all parameters, required first (Symbol's).
  def self.all_parameters(model_symbol, flavor)
    required_parameters(model_symbol, flavor) +
    optional_parameters(model_symbol, flavor)
  end

  # Get the parameters declarations.
  def parameter_declarations
    self.class.parameter_declarations(model_symbol, flavor)
  end

  # Return a list of required parameters sorted by name (Symbol's).
  def required_parameters
    self.class.required_parameters(model_symbol, flavor)
  end

  # Return a list of optional parameters sorted by name (Symbol's).
  def optional_parameters
    self.class.optional_parameters(model_symbol, flavor)
  end

  # Return a list of all parameters, required first (Symbol's).
  def all_parameters
    required_parameters + optional_parameters
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
    elsif val.blank?
      nil
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
          val.is_a?(String) && val.match(/^[1-9]\d*$/) or
          # (blasted admin user has id = 0!)
          val.is_a?(String) && (val == '0') && (arg == :user)
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
    self.join     = []
    self.tables   = []
    self.where    = []
    self.group    = ''
    self.order    = ''
    self.executor = nil

    # Setup query for the given flavor.
    send("initialize_#{flavor}")

    # Give models ability to customize.
    if respond_to?("initialize_#{model_string.underscore}")
      send("initialize_#{model_string.underscore}")
    end

    # Give all queries the ability to order via simple :by => :name mechanism.
    superclass_initialize_order

    # Perform final global initialization.
    superclass_initialize_global
  end

  # Do mechanics of the :by => :type sorting mechanism.
  def superclass_initialize_order
    table = model.table_name

    by = params[:by]
    if by || order.blank?
      by ||= default_order

      # Allow any of these to be reversed.
      by = by.dup
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

  # Give all queries ability to override / customize low-level parameters.
  def superclass_initialize_global

    # Give subclass one last opportunity.
    initialize_global

    initialize_join(params[:join]) if params[:join]
    self.tables += params[:tables] if params[:tables]
    self.where  += params[:where]  if params[:where]
    self.group   = params[:group]  if params[:group]
    self.order   = params[:order]  if params[:order]
  end

  # Join parameter needs to be converted into an include-style "tree".  It just
  # evals the string, so the syntax is almost identical to what you're used to:
  #
  #   ":table, :table"
  #   ":table => :table"
  #   ":table => [:table, {:table => :table}]"
  #
  def initialize_join(val)
    self.join += val.map do |str|
      str.to_s.index(' ') ? eval(str) : str
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
    # Oh, crap, no we can't.  This fails down the line if bogus ids are given
    # to us in params[:ids].  query.result_ids returns the bogus ids, and
    # query.results returns nils for the bogus ids.  (It turns out that in
    # most cases this doesn't save us anything, anyway, because if the first
    # call upon the query is to retrieve results or result_ids, then this is
    # simply thrown away.  Oops.)
    # @result_ids = ids
  end

  ##############################################################################
  #
  #  :section: Initialization Helpers
  #
  ##############################################################################

  # Make a value safe for SQL.
  def escape(val)
    model.connection.quote(val)
  end
  def self.escape(val)
    User.connection.quote(val)
  end

  # Put together a list of ids for use in a "id IN (1,2,...)" condition.
  #
  #   set = clean_id_set(name.children)
  #   self.where << "names.id IN (#{set})"
  #
  def self.clean_id_set(ids)
    result = ids.map(&:to_i).uniq[0,MAX_ARRAY].map(&:to_s).join(',')
    result = '-1' if result.blank?
    return result
  end
  def clean_id_set(ids); self.class.clean_id_set(ids); end

  # Clean a pattern for use in LIKE condition.  Takes and returns a String.
  def self.clean_pattern(pattern)
    pattern.gsub(/[%'"\\]/) {|x| '\\' + x}.gsub('*', '%')
  end
  def clean_pattern(pattern); self.class.clean_pattern(pattern); end

  # Combine args into single parenthesized condition by anding them together.
  def self.and_clause(*args)
    if args.length > 1
      '(' + args.join(' AND ') + ')'
    else
      args.first
    end
  end
  def and_clause(*args); self.class.and_clause(*args); end

  # Combine args into single parenthesized condition by oring them together.
  def self.or_clause(*args)
    if args.length > 1
      '(' + args.join(' OR ') + ')'
    else
      args.first
    end
  end
  def or_clause(*args); self.class.or_clause(*args); end

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
  def self.google_parse(str)
    goods = []
    bads  = []
    if (str = str.to_s.strip_squeeze) != ''
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
  def google_parse(str); self.class.google_parse(str); end

  # Put together a bunch of SQL conditions that describe a given search.
  def google_conditions(search, field)
    goods = search.goods
    bads  = search.bads
    ands = []
    ands += goods.map do |good|
      or_clause(*good.map {|str| "#{field} LIKE '%#{clean_pattern(str)}%'"})
    end
    ands += bads.map {|bad| "#{field} NOT LIKE '%#{clean_pattern(bad)}%'"}
    [ands.join(' AND ')]
  end

  # Simple class to hold the results of +google_parse+.  It just has two
  # attributes, +goods+ and +bads+.
  class GoogleSearch
    attr_accessor :goods, :bads
    def initialize(args={})
      self.goods = args[:goods]
      self.bads = args[:bads]
    end
    def blank?
      !goods.any? && !bads.any?
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
    our_where   = calc_where_clause(our_where)
    our_group   = args[:group] || self.group
    our_order   = args[:order] || self.order
    our_order   = reverse_order(self.order) if our_order == :reverse
    our_limit   = args[:limit]

    # Tack id at end of order to disambiguate the order.
    # (I despise programs that render random results!)
    if !our_order.blank? and
       !our_order.match(/.id( |$)/)
      our_order += ", #{model.table_name}.id DESC"
    end

    sql = %(
      SELECT #{our_select}
      FROM #{our_from}
    )
    sql += "  WHERE #{our_where}\n"    if !our_where.blank?
    sql += "  GROUP BY #{our_group}\n" if !our_group.blank?
    sql += "  ORDER BY #{our_order}\n" if !our_order.blank?
    sql += "  LIMIT #{our_limit}\n"    if !our_limit.blank?

    self.last_query = sql
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
    implicits = [model.table_name] + our_tables
    result = implicits.uniq.map {|x| "`#{x}`"}.join(', ')
    if our_join
      result += ' '
      result += calc_join_conditions(model.table_name, our_join).join(' ')
    end
    return result
  end

  # Extract a complete list of tables being used by this query.  (Combines
  # this table (+model.table_name+) with tables from +join+ with custom-joined
  # tables from +tables+.)
  def table_list(our_join=join, our_tables=tables)
    flatten_joins([model.table_name] + our_join + our_tables, false).uniq
  end

  # Flatten join "tree" into a simple Array of Strings.  Set +keep_qualifiers+
  # to +false+ to tell it to remove the ".column" qualifiers on ambiguous
  # table join specs.
  def flatten_joins(arg=join, keep_qualifiers=true)
    result = []
    if arg.is_a?(Hash)
      for key, val in arg
        key = key.to_s.sub(/\..*/, '') if !keep_qualifiers
        result << key.to_s
        result += flatten_joins(val)
      end
    elsif arg.is_a?(Array)
      result += arg.map {|x| flatten_joins(x)}.flatten
    else
      arg = arg.to_s.sub(/\..*/, '') if !keep_qualifiers
      result << arg.to_s
    end
    return result
  end

  # Figure out which additional conditions we need to connect all the joined
  # tables.  Note, +to+ can be an Array and/or tree-like Hash of dependencies.
  # (I believe it is identical to how :include is done in ActiveRecord#find.)
  def calc_join_conditions(from, to, done=[from.to_s])
    result = []
    from = from.to_s
    if to.is_a?(Hash)
      for key, val in to
        result += calc_join_condition(from, key.to_s, done)
        result += calc_join_conditions(key.to_s, val, done)
      end
    elsif to.is_a?(Array)
      result += to.map {|x| calc_join_conditions(from, x, done)}.flatten
    else
      result += calc_join_condition(from, to.to_s, done)
    end
    return result
  end

  # Create SQL 'JOIN ON' clause to join two tables.  Tack on an exclamation to
  # make it an outer join.  Tack on '.field' to specify alternate association.
  def calc_join_condition(from, to, done)
    from = from.sub(/\..*/, '')
    to = to.dup
    do_outer = to.sub!(/!$/, '')

    result = []
    if !done.include?(to)
      done << to

      # Check for "forward" join first, e.g., if joining from observatons to
      # rss_logs, use "observations.rss_log_id = rss_logs.id", because that will
      # take advantage of the primary key on rss_logs.id.
      if col = (join_conditions[from.to_sym] && join_conditions[from.to_sym][to.to_sym])
        to.sub!(/\..*/, '')
        target_table = to

      # Now look for "reverse" join.  (In the above example, and this was how it
      # used to be, it would be "observations.id = rss_logs.observation_id".)
      elsif col = (join_conditions[to.to_sym] && join_conditions[to.to_sym][from.to_sym])
        to.sub!(/\..*/, '')
        target_table = to
        from, to = to, from
      else
        raise("Don't know how to join from #{from} to #{to}.")
      end

      # Calculate conditions.
      if col == :obj || col == :object
        conds = "#{from}.#{col}_id = #{to}.id AND " +
                "#{from}.#{col}_type = '#{to.singularize.camelize}'"
      else
        conds = "#{from}.#{col} = #{to}.id"
      end

      # Put the whole JOIN clause together.
      if do_outer
        result << ["LEFT OUTER JOIN `#{target_table}` ON #{conds}"]
      else
        result << ["JOIN `#{target_table}` ON #{conds}"]
      end
    end
    return result
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
  #  *NOTE*: These methods are not allowed for queries that have a customized
  #  +executor+ (e.g., google-style searches).
  #
  ##############################################################################

  # Execute query after wrapping select clause in COUNT().
  def select_count(args={})
    initialize_query
    if executor
      executor.call(args).length
    else
      select = args[:select] || "DISTINCT #{model.table_name}.id"
      args = args.merge(:select => "COUNT(#{select})")
      model.connection.select_value(query(args)).to_i
    end
  end

  # Call model.connection.select_value.
  def select_value(args={})
    initialize_query
    if executor
      executor.call(args).first.first
    else
      model.connection.select_value(query(args))
    end
  end

  # Call model.connection.select_values.
  def select_values(args={})
    initialize_query
    if executor
      executor.call(args).map(&:first)
    else
      model.connection.select_values(query(args))
    end
  end

  # Call model.connection.select_rows.
  def select_rows(args={})
    initialize_query
    if executor
      executor.call(args)
    else
      model.connection.select_rows(query(args))
    end
  end

  # Call model.connection.select_one.
  def select_one(args={})
    initialize_query
    if executor
      executor.call(args).first
    else
      model.connection.select_one(query(args))
    end
  end

  # Call model.connection.select_all.
  def select_all(args={})
    initialize_query
    raise "This query doesn't support low-level access!" if executor
    model.connection.select_all(query(args))
  end

  # Call model.find_by_sql.
  def find_by_sql(args={})
    initialize_query
    raise "This query doesn't support low-level access!" if executor
    model.find_by_sql(query_all(args))
  end

  ##############################################################################
  #
  #  :section: High-Level Queries
  #
  #  Note that most of these methods accept a few optional arguments.  For
  #  example, all methods that return instantiated results accept +:include+
  #  which is passed in to <tt>model.all</tt>.
  #
  #  join::           Add extra join clause(s) to query.
  #  where::          Add extra condition(s) to query.
  #  limit::          Put a limit on the number of results from the raw query.
  #  include::        Eager-load these associations when instantiating results.
  #
  #  Add additional arguments to the three "global" Arrays immediately below:
  #
  #  RESULTS_ARGS::       Args passed to +select_values+ via +result_ids+.
  #  PAGINATE_ARGS::      Args passed to +paginate_ids+.
  #  INSTANTIATE_ARGS::   Args passed to +model.all+ via +instantiate+.
  #
  ##############################################################################

  # Args accepted by +results+, +result_ids+, +num_results+.  (These are passed
  # through into +select_values+.)
  RESULTS_ARGS = [:join, :where, :limit]

  # Args accepted by +paginate+ and +paginate_ids+.
  PAGINATE_ARGS = []

  # Args accepted by +instantiate+ (and +paginate+ and +results+ since they
  # call +instantiate+, too).
  INSTANTIATE_ARGS = [:include]

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

  # Does this query join to the given table?  (Takes a Symbol; distinguishes
  # between the different ways to join to a given table via the "table.field"
  # syntax used in +join_conditions+ table.)
  def uses_join?(join_spec)

    def uses_join_sub(tree, arg) # :nodoc:
      case tree
      when Array
        tree.any? {|sub| uses_join_sub(sub, arg)}
      when Hash
        tree.keys.include?(arg) or
        tree.values.any? {|sub| uses_join_sub(sub, arg)}
      else
        (tree == arg)
      end
    end

    initialize_query if !initialized?
    uses_join_sub(join, join_spec)
  end

  # Number of results the query returns.
  def num_results(args={})
    result_ids(args).length
  end

  # Array of all results, just ids.
  def result_ids(args={})
    expect_args(:result_ids, args, RESULTS_ARGS)
    @result_ids ||= if !need_letters
      select_values(args).map(&:to_i)
    else

      # Include first letter of paginate-by-letter field right away; there's
      # typically no avoiding it.  This optimizes away an extra query or two.
      self.letters = map = {}
      ids = []
      select = "DISTINCT #{model.table_name}.id, LEFT(#{need_letters},1)"
      for id, letter in select_rows(args.merge(:select => select))
        if letter.match(/[a-zA-Z]/)
          map[id.to_i] = letter.upcase
        end
        ids << id.to_i
      end
      ids
    end
  end

  # Array of all results, instantiated.
  def results(args={})
    instantiate_args, results_args = split_args(args, INSTANTIATE_ARGS)
    instantiate(result_ids(results_args), instantiate_args)
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
  def index(arg, args={})
    if arg.is_a?(ActiveRecord::Base)
      result_ids(args).index(arg.id)
    else
      result_ids(args).index(arg.to_s.to_i)
    end
  end

  # Make sure we requery if we change the letter field.
  def need_letters=(x)
    if !x.is_a?(String)
      raise "You need to pass in a SQL expression to 'need_letters'."
    elsif @need_letters != x
      @result_ids = nil
      @need_letters = x
    end
  end

  # Returns a subset of the results (as ids).  Optional arguments:
  # (Also accepts args for
  def paginate_ids(paginator, args={})
    results_args, args = split_args(args, RESULTS_ARGS)
    expect_args(:paginate_ids, args, PAGINATE_ARGS)

    # Get list of letters used in results.
    if need_letters
      num_results
      map = letters
      paginator.used_letters = map.values.uniq

      # Filter by letter. (paginator keeps letter upper case, as do we)
      if letter = paginator.letter
        @result_ids = @result_ids.select {|id| map[id] == letter}
      end
    end

    # Paginate remaining results.
    paginator.num_total = num_results(results_args)
    from, to = paginator.from, paginator.to
    result_ids(results_args)[from..to] || []
  end

  # Returns a subset of the results (as ActiveRecord instances).
  # (Takes same args as both +instantiate+ and +paginate_ids+.)
  def paginate(paginator, args={})
    paginate_args, instantiate_args = split_args(args, PAGINATE_ARGS)
    instantiate(paginate_ids(paginator, paginate_args), instantiate_args)
  end

  # Instantiate a set of records given as an Array of ids.  Returns a list of
  # ActiveRecord instances in the same order as given.  Optional arguments:
  # +include+:: Tables to eager load (see argument of same name in
  #             ActiveRecord::Base#find for syntax).
  def instantiate(ids, args={})
    expect_args(:instantiate, args, INSTANTIATE_ARGS)
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
    @results    = nil
    @result_ids = nil
    @letters    = nil
  end

  ##############################################################################
  #
  #  :section: Sequence Operators
  #
  ##############################################################################

  # Return current place in results, as an id.  (Returns nil if not set yet.)
  def current_id
    @current_id
  end

  # Set current place in results; takes id (String or Fixnum).
  def current_id=(id)
    @save_current_id = @current_id = id.to_s.to_i
  end

  # Reset current place in results to the place last given in a "current=" call.
  def reset
    @current_id = @save_current_id
  end

  # Return current place in results, instantiated.  (Returns nil if not set
  # yet.)
  def current(*args)
    @current_id ? instantiate([@current_id], *args).first : nil
  end

  # Set current place in results; takes instance or id (String or Fixnum).
  def current=(arg)
    if arg.is_a?(model)
      @results ||= {}
      @results[arg.id] = arg
      self.current_id = arg.id
    else
      self.current_id = arg
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
        @current_id = id
      else
        new_self.current_id = id
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
    index = result_ids.index(current_id)
    if !index
      new_self = nil
    elsif index > 0
      if new_self == self
        @current_id = result_ids[index - 1]
      else
        new_self.current_id = result_ids[index - 1]
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
    index = result_ids.index(current_id)
    if !index
      new_self = nil
    elsif index < result_ids.length - 1
      if new_self == self
        @current_id = result_ids[index + 1]
      else
        new_self.current_id = result_ids[index + 1]
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
        @current_id = id
      else
        new_self.current_id = id
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
  # method is called on the inner query, returning the +current_id+ of the outer
  # query for that result.
  def get_outer_current_id
    if outer_current_id
      outer_current_id.call(self)
    else
      params[outer.model.type_tag]
    end
  end

  # Create a new copy of this query corresponding to the new outer query.
  def new_inner(new_outer)
    new_params = params.merge(:outer => new_outer.id)
    if setup_new_inner_query
      setup_new_inner_query.call(new_params, new_outer)
    else
      new_params[new_outer.model.type_tag] = new_outer.current_id
    end
    self.class.lookup_and_save(model, flavor, new_params)
  end

  # Create a new copy of this query if the outer query changed, otherwise
  # returns itself unchanged.
  def new_inner_if_necessary(new_outer)
    if !new_outer
      nil
    elsif new_outer.current_id == get_outer_current_id
      self
    else
      self
      new_inner(new_outer)
    end
  end

  # Move outer query to first place.
  def outer_first
    outer.current_id = get_outer_current_id
    new_inner_if_necessary(outer.first)
  end

  # Move outer query to previous place.
  def outer_prev
    outer.current_id = get_outer_current_id
    new_inner_if_necessary(outer.prev)
  end

  # Move outer query to next place.
  def outer_next
    outer.current_id = get_outer_current_id
    new_inner_if_necessary(outer.next)
  end

  # Move outer query to last place.
  def outer_last
    outer.current_id = get_outer_current_id
    new_inner_if_necessary(outer.last)
  end

  ##############################################################################
  #
  #  :stopdoc: Other Stuff
  #
  ##############################################################################

  # Raise an error if caller passed any unexpected arguments.
  def expect_args(method, args, expect) # :nodoc:
    extra_args = args.keys - expect
    if !extra_args.empty?
      raise "Unexpected arguments to Query##{method}: #{extra_args.inspect}"
    end
  end

  # Split up a Hash of arguments, putting all the ones in the given list in
  # the first of two Hash's, and all the rest in the other.  Returns two Hash's.
  def split_args(args, keys_in_first) # :nodoc:
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

  # Safely add to :where in +args+.  Dups <tt>args[:where]</tt>, casts it into
  # an Array, and returns the new Array.
  def extend_where(args)
    extend_arg(args, :where)
  end

  # Safely add to :join in +args+.  Dups <tt>args[:join]</tt>, casts it into
  # an Array, and returns the new Array.
  def extend_join(args)
    extend_arg(args, :join)
  end

  # Safely add to +arg+ in +args+.  Dups <tt>args[arg]</tt>, casts it into
  # an Array, and returns the new Array.
  def extend_arg(args, arg)
    case old_arg = args[arg]
    when Symbol, String
      args[arg] = [old_arg]
    when Array
      args[arg] = old_arg.dup
    else
      args[arg] = []
    end
  end
end

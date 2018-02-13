# encoding: utf-8
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
#    query = Query.lookup(:Observation, :by_user, user: @user)
#
#  Get observations in the three sections of show_name:
#  1) observations whose consensus is @name
#  2) observations whose consensus is synonym of @name
#  3) observations with non-consensus naming that is a synonym of @name
#
#    query = Query.lookup(:Observation, :of_name, name: @name)
#    query = Query.lookup(:Observation, :of_name,
#                         name: @name, synonyms: :exclusive)
#    query = Query.lookup(:Observation, :of_name,
#                         name: @name, synonyms: :all, nonconsensus: :exclusive)
#
#  You may further tweak a query after it's been created:
#
#    query = Query.lookup(:Observation)
#    query.join  << :names
#    query.where << 'names.correct_spelling_id IS NULL'
#    query.order =  'names.sort_name ASC'
#
#  Now you may execute it in various ways:
#
#    num_results = query.num_results
#    ids         = query.result_ids
#    instances   = query.results
#
#  You also have access to lower-level operations:
#
#    ids   = query.select_values(where: 'names.display_name LIKE "A%"')
#    ids   = query.select_values(order: 'names.sort_name ASC')
#    names = query.select_values(select: 'names.display_name')
#
#    # This is the most efficient way to make Query work with ActiveRecord:
#    # This lets you customize the query, then automatically tells it to select
#    # all the fields ActiveRecord::Base#find_by_sql needs.
#    names = query.find_by_sql(where: ...)
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
#    query.need_letters = 'names.sort_name'
#    @pages = paginate_letters
#    @names = query.paginate(@pages)
#
#  == Sequence Operators
#
#  The "correct" usage of the sequence operators is subtle and inflexible due
#  to the complexities of the query potentially being nested.  This is how it
#  is designed to work:
#
#    query = Query.lookup(:Image)
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
#    inner = create_query(:Image, :inside_observation, outer: outer,
#                         observation: @observation)
#    inner.results each do |image|
#      link_to(image,
#        add_query_param({action: :show_image, id: image.id}, inner))
#    end
#
#    # Now show_image can be oblivous:
#    query = find_or_create_query(:Image)
#    link_to("Prev",
#      add_query_param({action: :prev_image, id: image.id}, query))
#    link_to("Next",
#      add_query_param({action: :next_image, id: image.id}, query))
#    link_to("Back",
#      add_query_param({action: :show_observation, id: image.id, query))
#
#    # And this is how prev and next work:
#    query = find_or_create_query(:Image, current: params[:id].to_s)
#    if new_query = query.next
#      redirect_to(
#        add_query_param({action: :show_image, id: new_query.current_id},
#                        new_query)
#      )
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
#  The first and last sequence operators ignore result_ids (TODO - no need to
#  ignore if not nested or if outer is already at end).  However, they are able
#  to execute optimized queries that return only the first or last result.
#
#  None of the low-level queries are cached in any way.
#
#  == Attributes
#  model::              Class of model results belong to.
#  flavor::             Type of query (Symbol).
#  outer::              Outer Query (if nested).
#  params::             Hash of parameters used to create query.
#  current::            Current location in query (for sequence operators).
#  join::               Tree of tables used in query.
#  tables::             Extra tables which have been joined explicitly.
#  where::              List of WHERE clauses in query.
#  group::              GROUP BY clause in query.
#  order::              ORDER BY clause in query.
#
#  == Class Methods
#  lookup::             Instantiate Query of given model, flavor and params.
#  deserialize::        Instantiate Query described by a string.
#
#  ==Instance Methods
#  serialize::          Returns string which describes the Query completely.
#  initialized?::       Has this query been initialized?
#  coerce::             Coerce a query for one model into a query for another.
#  coercable?::         Check if +coerce+ will work (but don't actually do it).
#
#  ==== Sequence operators
#  first::              Go to first result.
#  prev::               Go to previous result.
#  next::               Go to next result.
#  last::               Go to last result.
#  reset::              Go back to original result.
#
#  ==== Low Level Query Operations
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
#
#  ==== High Level Query Operations
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
#  ==== Instance Variables
#  @initialized::       Boolean: has +initialize_query+ been called yet?
#  @current_id::        Integer: current place in results.
#  @save_current_id::   Integer: saved copy of +@current_id+ for +reset+.
#  @result_ids::        Array of Integer: all results.
#  @results::           Hash: maps ids to instantiated records.
#  @letters::           Cache of first-letters (if +need_letters given).
#  @outer::             AbstractQuery: cached copy of outer query (nested
#                       queries only).
#  @params_cache::      Hash: where instances passed in via params are cached.
#
module Query
  def self.new(model, flavor = :all, params = {}, current = nil)
    klass = "Query::#{model}#{flavor.to_s.camelize}".constantize
    query = klass.new
    query.params = params
    query.validate_params
    query.current = current if current
    query
  end

  # Delegate all these to Query::Base class.

  def self.deserialize(*args)
    Query::Base.deserialize(*args)
  end

  def self.safe_find(*args)
    Query::Base.safe_find(*args)
  end

  def self.find(*args)
    Query::Base.find(*args)
  end

  def self.lookup_and_save(*args)
    Query::Base.lookup_and_save(*args)
  end

  def self.lookup(*args)
    Query::Base.lookup(*args)
  end
end

# frozen_string_literal: true

#
#  = Query Model
#
#  This class encapsulates a hash of params that can produce an ActiveRecord
#  statement for a database query, that looks up one or more objects of a
#  given type, matching certain conditions in a certain order.
#
#  Queries are specified by a model.  The model specifies which kind
#  of objects are being requested, e.g. :Name or :Observation. They are
#  dyamically joined with any number of additional tables, as required by
#  sorting and selection conditions.
#
#  To filter query results, you can send additional parameters.  For example,
#  create_query(:Comment for_user: user.id) retrieves comments posted on a
#  given user's observations.  Query saves the parameters alongside the model,
#  and together these fully specify a query that may be recreated and
#  executed at a later time, even potentially by another user (e.g., if users
#  share links that have query specs embedded in them). They can be serialized
#  and printed as a permalink, or carried along in the session while the user
#  is navigating around related records.
#
#  `initialize_query` is the internal method that translates the params and
#  their values to ActiveRecord scopes with the same names, without executing
#  the query. (Scopes are independent of Query, and need to be defined on each
#  model.) Only the public accessors like `results` actually load the database
#  records for the current page of results.
#
#  Query also keeps track of "where you are in the query".  Browsing through
#  filtered results, if you visit a "show" page, you can continue navigating
#  through the same results via the "next" and "prev" links on the show page,
#  within the same query — as if you were paging through results in the index.
#
#  Each model has a default search order (:default), which is used by the prev
#  and next actions when the specified query no longer exists.  For example, if
#  you click on an observation from the main index, prev and next travserse the
#  results of an :Observation order_by: :rss_log query.  If the user comes back
#  a day later, this query will have been culled by the garbage collector (see
#  below), so prev and next need to be able to create a default query on the
#  fly.
#
#  == Example Usage
#
#  Get observations created by @user:
#
#    query = Query.lookup(:Observation, by_users: [@user])
#
#  You may further tweak a query after it's been created:
#
#    query = Query.lookup(:Observation)
#    query.add_join(:names)
#    query.where << 'names.correct_spelling_id IS NULL'
#    query.order = 'names.sort_name ASC'
#
#  Now you may execute it in various ways:
#
#    num_results = query.num_results
#    ids         = query.result_ids
#    instances   = query.results
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
#  Finally, Query's know how to work with PaginationData:
#
#    # In controller:
#    query = create_query(:Name)
#    @pagination_data = number_pagination_data
#    @names = query.paginate(@pagination_data)
#
#    # Or if you want to paginate by letter first, then page number:
#    query = create_query(:Name)
#    query.need_letters = 'names.sort_name'
#    @pagination_data = letter_pagination_data
#    @names = query.paginate(@pagination_data)
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
#  The first and last sequence operators ignore result_ids.  However, they are
#  able to execute optimized queries that return only the first or last result.
#
#  == Attributes
#  model::              Class of model results belong to.
#  params::             Hash of parameters used to create query.
#  current::            Current location in query (for sequence operators).
#  subqueries::         Cache of subquery Query instances, used for filtering.
#
#  == Class Methods
#  lookup::             Instantiate Query of given model, flavor and params.
#  lookup_and_save::    Ditto, plus save the QueryRecord
#  find::               Find a QueryRecord id and reinstantiate a Query from it.
#  safe_find::          Same as above, with rescue.
#  rebuild_from_description:: Instantiate Query described by description string.
#  related?::                 Can a query of this model be converted to a
#                             subquery filtering results of another model?
#  current_or_related_query:: Convert queries from one model to another; can be
#                             called recursively. To avoid repetitive recursion,
#                             it checks for a nested query that may be for the
#                             intended target model.
#
#  == Instance Methods
#  initialized?::       Has this query been initialized?
#  serialize::          Returns string which describes the Query completely.
#  sql::                Returns scopes.to_sql for comparison and tests.
#  query::              scopes.all, the ActiveRecord statement of the query.
#
#  ==== Sequence operators
#  first::              Go to first result.
#  prev::               Go to previous result.
#  next::               Go to next result.
#  last::               Go to last result.
#  reset::              Go back to original result.
#
#  ==== Result accessors
#
#  NOTE: Calling most of these will `initialize_query`,
#        i.e., instantiate the requested page of query results.
#
#  num_results::        Number of results the query returns.
#  results::            Array of all results, instantiated.
#  result_ids::         Array of all results, just ids.
#  index::              Index of a given id or object in the results.
#  paginate::           Array of subset of results, instantiated.
#  paginate_ids::       Array of subset of results, just ids.
#  clear_cache::        Clear results cache.
#
#  == Internal Variables
#
#  ==== Instance Variables
#  @initialized::       Boolean: has +initialize_query+ been called yet?
#  @scopes::            Chain of scopes, called on params during initialization.
#  @current_id::        Integer: current place in results.
#  @save_current_id::   Integer: saved copy of +@current_id+ for +reset+.
#  @result_ids::        Array of Integer: all results.
#  @results::           Hash: maps ids to instantiated records.
#  @letters::           Cache of first-letters (if +need_letters given).
#  @params_cache::      Hash: where instances passed in via params are cached.
#  @last_query::        Alias for `sql`.
#
#  NOTE: The Query::Model classes do not inherit from this class.
#        They inherit from Query::Base, which does not inherit from this either.
#        This class is simply a convenience delegator/accessor for class
#        methods that may be called from outside Query, like `Query.lookup`
#
class Query
  include Query::Modules::ClassMethods

  def self.new(model, params = {}, current = nil)
    klass = "Query::#{model.to_s.pluralize}".constantize
    case klass.new
    when Query::BaseAR
      new_ar(klass, params, current)
    when Query::BaseAM
      new_am(klass, params, current)
    end
  end

  def self.new_am(klass, params, current)
    query = klass.new(params)
    query.params = query.attributes # initialize params for cleaning/validation
    query.subqueries = {}
    query.current = current if current
    query.valid = query.valid? # reinitializes params after cleaning/validation
    query
  end

  def self.new_ar(klass, params, current)
    query = klass.new
    query.params = params
    query.subqueries = {}
    query.validate_params
    query.current = current if current
    # query.initialize_query # if you want the attributes right away, like `sql`
    query
  end

  delegate :default_order, to: :class
end

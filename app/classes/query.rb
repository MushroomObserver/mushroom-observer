# frozen_string_literal: true

#
#  = Query Model
#
#  This model encapsulates a database query that looks up one or more objects
#  of a given type that match certain conditions in a certain order.  Queries
#  are dyamically joined with any number of additional tables, as required by
#  sorting and selection conditions.
#
#  Queries are specified by a model.  The model specifies which kind
#  of objects are being requested, e.g. :Name or :Observation.
#
#  Each model has a default search flavor (:default), which is used by the prev
#  and next actions when the specified query no longer exists.  For example, if
#  you click on an observation from the main index, prev and next travserse the
#  results of an :Observation order_by: :rss_log query.  If the user comes back
#  a day later, this query will have been culled by the garbage collector (see
#  below), so prev and next need to be able to create a default query on the
#  fly.  In this case it may be :Observation :all (see default_flavors array
#  below).
#
#  In addition, some queries require additional parameters.  For example,
#  :Comment :for_user requires a user_id (it retrieves comments posted on a
#  given user's observations).  These parameters are saved along-side the model,
#  and together these fully specify a query so that it may be
#  recreated and executed at a later time, even potentially by another user
#  (e.g., if users share links that have query specs embedded in them).
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
#    @pagination_data = pagination_data_numbers
#    @names = query.paginate(@pagination_data)
#
#    # Or if you want to paginate by letter first, then page number:
#    query = create_query(:Name)
#    query.need_letters = 'names.sort_name'
#    @pagination_data = pagination_data_letters
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
#  The first and last sequence operators ignore result_ids (TODO - no need to
#  ignore if not nested or if outer is already at end).  However, they are able
#  to execute optimized queries that return only the first or last result.
#
#  None of the low-level queries are cached in any way.
#
#  == Attributes
#  model::              Class of model results belong to.
#  params::             Hash of parameters used to create query.
#  current::            Current location in query (for sequence operators).
#  join::               Tree of tables used in query.
#  tables::             Extra tables which have been joined explicitly.
#  where::              List of WHERE clauses in query.
#  group::              GROUP BY clause in query.
#  order::              ORDER BY clause in query.
#  selects::            SELECT clause in query.
#  subqueries::         Cache of subquery Query instances, used for filtering.
#
#  == Class Methods
#  lookup::             Instantiate Query of given model, flavor and params.
#  lookup_and_save::    Ditto, plus save the QueryRecord
#  find::               Find a QueryRecord id and reinstantiate a Query from it.
#  safe_find::          Same as above, with rescue.
#  rebuild_from_description:: Instantiate Query described by description string.
#  related?::           Can a query of this model be converted to a subquery
#                       filtering results of another model?
#  current_or_related_query:: Convert queries from one model to another; can be
#                             called recursively. To avoid repetitive recursion,
#                             it checks for a nested query that may be for the
#                             intended target model.
#
#  ==Instance Methods
#  serialize::          Returns string which describes the Query completely.
#  initialized?::       Has this query been initialized?
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
#  NOTE: The Query::Model classes do not inherit from this class.
#        They inherit from Query::Base.
#        This class is simply a convenience delegator for class methods that
#        need to be called from outside Query, like `Query.lookup`
#
class Query
  include Query::Modules::ClassMethods

  def self.new(model, params = {}, current = nil)
    klass = "Query::#{model.to_s.pluralize}".constantize
    query = klass.new
    query.params = params
    query.subqueries = {}
    query.validate_params
    query.current = current if current
    # query.initialize_query # if you want the attributes right away
    query
  end

  delegate :default_order, to: :class
end

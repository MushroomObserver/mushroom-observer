# frozen_string_literal: true

##############################################################################
#
#  :section: Initialization
#
#  Helper methods for turning Query parameters into AR conditions.
#
#  Query.new basically accepts a hash of params, validates them and turns them
#  into attributes describing analogous AR scopes, but does not create the
#  scope chain yet.
#
#  To get the results for an :index page or for pagination, the methods in
#  `Query::Modules::Results` need to call `initialize_query`, which makes the
#  scope chain of the Query instance accessible via `#query`.
#
#  Example:
#
#  query = Query.new(:Observation, has_public_lat_lng: true)
#
#    This gives you `query` as a Query instance with validated `params`
#    you can inspect at `query.params`, `{ has_public_lat_lng: true }`
#
#    To use the query, though, you'd call:
#
#  query.scope
#
#    This is the same as calling:
#
#  Observation.has_public_lat_lng(true)
#
#    Note that `query.scope` does not return instantiated records.
#    It just gives you the complete scope chain for the current Query that you
#    can call, continue chaining, select from, get first(15), etc.
#
#  query.scope.limit(15) == Observation.has_public_lat_lng(true).limit(15)
#  query.scope.where(user: 252) == Observation.has_public_lat_lng(true).
#                                  where(user: 252)
#
#    Possible confusion: if you call a scope in the console, you will note
#    that `rails console` DOES instantiate the results. But rest assured
#    this does not happen in live code; an ActiveRecord scope is a "handler"
#    that is as inert as passing around an SQL string. It doesn't fire a
#    database query until you execute it or assign it to a variable,
#    like `results = Observation.all` or `results = query.scope`.
#
#  METHODS:
#
#  initialized?::     Has the Query instance been initialized?
#  initialize_query:: Send the params to AR model scopes.
#  scope::            The whole scope chain defined by the instance attributes.
#  sql::              Returns the SQL string that the scopes generate from AR.
#                     Same as calling `query.scope.to_sql`.
#
#  Private methods explained below.
#
###############################################################################

module Query::Modules::Initialization
  attr_accessor :scopes

  def initialized?
    @initialized ? true : false
  end

  def initialize_query
    @initialized = true
    @scopes      = model
    initialize_scopes
  end

  def sql
    initialize_query unless initialized?

    @sql = scope.to_sql
  end

  def scope
    initialize_query unless initialized?

    @scope = scopes.all
  end

  private

  def initialize_scopes
    initialize_parameter_set
    filter_misspellings_for_name_queries
    apply_rss_log_content_filters
    add_default_order_if_none_specified
  end

  def initialize_parameter_set
    sendable_params.each do |param, val|
      next if (param != :id_in_set && skippable_values.include?(val.to_s)) ||
              (param == :id_in_set && val.nil?) # keep empty array

      @scopes = if val.is_a?(Hash)
                  @scopes.send(param, **val)
                else
                  @scopes.send(param, val)
                end
    end
  end

  # We don't `compact` sendable_params, in order to keep empty arrays for
  # `:id_in_set`. We also do want `false` values, so we can't check `blank?`
  def skippable_values
    @skippable_values = ["[]", "{}", "", nil].freeze
  end

  # For most queries, these are the `scope_parameters` defined in Query::Base.
  # Makes sure `order_by` comes "last" in the hash, because some params may
  # reset order.
  # For RssLogs, removes any content filter params before passing to scopes
  # since they're already handled in subqueries above.
  def sendable_params
    sendable = params.slice(*scope_parameters)
    order_by = sendable.delete(:order_by)
    sendable[:order_by] = order_by if order_by.present?
    return sendable unless model == RssLog

    sendable.except(*content_filter_parameters.keys)
  end

  # Most name queries are filtered to remove misspellings.
  # This filters misspellings only if the param was not passed.
  def filter_misspellings_for_name_queries
    return if model != Name || !params[:misspellings].nil?

    @scopes = @scopes.with_correct_spelling
  end

  ##############################################################################

  # In the case of RssLogs with content filters, we handle building the scope
  # in Query, because it's the only place where we know which "types" of
  # log were requested, and because one content filter may apply to two types.
  def apply_rss_log_content_filters
    return unless model == RssLog && active_filters.present?

    @scopes = @scopes.content_filters(params)
  end

  def active_filters
    @active_filters ||= params.slice(*content_filter_parameters.keys).compact
  end

  ##############################################################################

  def add_default_order_if_none_specified
    return if params[:order_by].present?

    @scopes = @scopes.order_by_default
  end

  # array of max of MO.query_max_array unique ids for use with Arel "in"
  #    where(<x>.in(limited_id_set(ids)))
  def limited_id_set(ids)
    ids.map(&:to_i).uniq[0, MO.query_max_array]
  end
end

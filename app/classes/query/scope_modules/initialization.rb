# frozen_string_literal: true

# Helper methods for turning Query parameters into AR conditions.
module Query::ScopeModules::Initialization
  attr_accessor :scopes, :last_query

  def initialized?
    @initialized ? true : false
  end

  def initialize_query
    @initialized = true
    @scopes      = model
    initialize_scopes
    @last_query = sql
  end

  def sql
    initialize_query unless initialized?

    @sql = query.to_sql
  end

  def query
    initialize_query unless initialized?

    @query = scopes.all
  end

  def initialize_scopes
    initialize_parameter_set
    filter_misspellings_for_name_queries
    send_rss_log_content_filters_to_subqueries
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

  # For RssLogs, remove any content filter params before passing to scopes
  # since they're already handled in subqueries above.
  # Otherwise, these are the `scope_parameters` defined in Query::Base.
  def sendable_params
    sendable = params.slice(*scope_parameters)
    return sendable unless model == RssLog

    sendable.except(*content_filter_parameters.keys)
  end

  # Most name queries are filtered to remove misspellings.
  # This filters misspellings only if the param was not passed.
  def filter_misspellings_for_name_queries
    return if model != Name || !params[:misspellings].nil?

    @scopes = @scopes.with_correct_spelling
  end

  # In the case of RssLogs, send any content filter params to subqueries.
  # (Content filters may add params to RssLog queries that RssLog scopes
  # can't handle, because they're intended for one or more related models.)
  # Some params may go into more than one subquery if >1 `type` requested.
  def send_rss_log_content_filters_to_subqueries
    return if model != RssLog || !content_filters_present

    rss_logs_requested_filterable_types.each do |type|
      subquery_params = content_filter_subquery_params(type)
      next if subquery_params.blank?

      model_conditions = subquery_params.reduce([]) do |conds, (k, v)|
        conds << type.send(k, v)
      end
      association = type.name.underscore
      debugger
      @scopes = @scopes.left_outer_joins(:"#{association}").
                where("#{association}_id": nil).
                or(RssLog.merge(and_clause(*model_conditions)))
    end
  end

  # Query.new(:RssLog, region: "Canada", has_specimen: true).to_sql
  # SELECT DISTINCT rss_logs.id
  # FROM `rss_logs`
  # LEFT OUTER JOIN `observations` ON rss_logs.observation_id = observations.id
  # LEFT OUTER JOIN `locations` ON rss_logs.location_id = locations.id
  # WHERE (observations.id IS NULL OR
  #        ((observations.specimen IS TRUE AND
  #          CONCAT(', ', observations.where) LIKE '%, Canada')))
  # AND (locations.id IS NULL OR
  #      (CONCAT(', ', locations.name) LIKE '%, Canada')))
  # ORDER BY rss_logs.updated_at DESC, rss_logs.id DESC

  # Current types requested on the RssLog page that can have content filters
  # applied. Defaults to :all.
  def rss_logs_requested_filterable_types
    types = [:observation, :name, :location]
    active_types = case params[:type]
                   when nil, "", :all, "all"
                     types
                   when Array
                     params[:type]
                   when String
                     params[:type].split
                   end
    active_types.map { |type| type.to_s.camelize.constantize }
  end

  # Use Query::Filter.by_model to find any filters relevant to a model.
  def content_filter_subquery_params(model)
    Query::Filter.by_model(model).
      each_with_object({}) do |fltr, subquery_params|
        next if (val = params[fltr.sym]).to_s == ""

        subquery_params[fltr.sym] = val
      end
  end

  def content_filters_present
    @content_filters_present ||=
      params.slice(*content_filter_parameters.keys).compact.present?
  end

  def add_default_order_if_none_specified
    return if params[:order_by].present?

    @scopes = @scopes.order_by_default
  end

  # array of max of MO.query_max_array unique ids for use with Arel "in"
  #    where(<x>.in(limited_id_set(ids)))
  def limited_id_set(ids)
    ids.map(&:to_i).uniq[0, MO.query_max_array]
  end

  # FIXME put these in a module that we can include in scopes and here
  # Combine args into one parenthesized condition by ANDing them.
  def and_clause(*args)
    if args.length > 1
      # "(#{args.join(" AND ")})"
      starting = args.shift
      args.reduce(starting) { |result, arg| result.and(arg) }
    else
      args.first
    end
  end

  # Combine args into one parenthesized condition by ORing them.
  def or_clause(*args)
    if args.length > 1
      # "(#{args.join(" OR ")})"
      starting = args.shift
      args.reduce(starting) { |result, arg| result.or(arg) }
    else
      args.first
    end
  end
end

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

    @sql = scopes.all.to_sql
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

    rss_logs_requested_types.each do |model|
      subquery_params = content_filter_subquery_params(model)
      if subquery_params.present?
        @scopes = @scopes.send(:"#{model.name.downcase}_query",
                               **subquery_params)
      end
    end
  end

  # Current types requested on the RssLog page. Defaults to :all.
  def rss_logs_requested_types
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

  # Make a value safe for SQL.
  def escape(val)
    model.connection.quote(val)
  end

  # Put together a list of ids for use in a "id IN (1,2,...)" condition.
  #
  #   set = clean_id_set(name.children)
  #   @where << "names.id IN (#{set})"
  #
  def clean_id_set(ids)
    set = limited_id_set(ids).map(&:to_s).join(",")
    set.presence || "-1"
  end

  # array of max of MO.query_max_array unique ids for use with Arel "in"
  #    where(<x>.in(limited_id_set(ids)))
  def limited_id_set(ids)
    ids.map(&:to_i).uniq[0, MO.query_max_array]
  end

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

  # Add a join condition if it doesn't already exist.  There are two forms:
  #
  #   # Add join from root table to the given table:
  #   add_join(:observations)
  #     => join << :observations
  #
  #   # Add join from one table to another: (will create join from root to
  #   # first table if it doesn't already exist)
  #   add_join(:observations, :names)
  #     => join << {:observations => :names}
  #   add_join(:names, :descriptions)
  #     => join << {:observations => {:names => :descriptions}}
  #
  # def add_join(*)
  #   @join.add_leaf(*)
  # end

  # Same as add_join but can provide chain of more than two tables.
  # def add_joins(*args)
  #   if args.length == 1
  #     @join.add_leaf(args[0])
  #   elsif args.length > 1
  #     while args.length > 1
  #       @join.add_leaf(args[0], args[1])
  #       args.shift
  #     end
  #   end
  # end

  # Safely add to :where in +args+. Dups <tt>args[:where]</tt>,
  # casts it into an Array, and returns the new Array.
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
    args[arg] = case old_arg = args[arg]
                when Symbol, String
                  [old_arg]
                when Array
                  old_arg.dup
                else
                  []
                end
  end
end

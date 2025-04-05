# frozen_string_literal: true

# Helper methods for turning Query parameters into AR conditions.
module Query::Modules::Initialization
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

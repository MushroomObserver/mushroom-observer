module Query::Initializers::ObservationFilters
  include ::Filter

  def observation_filter_parameter_declarations
    {
      has_images?:   :string,
      has_specimen?: :string
    }
  end

  # Lets application controller easily check if we need to apply user's content
  # filter parameters to the current query.
  def observation_filters
    true
  end

  # Lets ApplicationController check whether to add default filters to
  # current query; defaults are added unless query already has
  # observation filter params, even if those filters are off.
  # This allows for overriding of default filters.
  def has_obs_filter_params?
    observation_filter_keys.any? {|k| params[k] != nil}
  end

  # Lets Query::RssLogBase check if whether to add filtered observations
  # to the current query.
  def any_observation_filter_is_on?
    observation_filter_keys.any? { |filter_sym| is_on?(filter_sym) }
  end

  # Does params[:x] == one of x's on_vals?
  # E.g., is_on?(:has_images) == true if
  #   params[:has_images] == "NOT NULL" || "NULL"
  def is_on?(filter_sym)
    return unless params[filter_sym]
    filter = eval(filter_sym.to_s)
    filter[:on_vals].include?(params[filter_sym])
  end

  def observation_filter_keys
    keys = observation_filter_parameter_declarations.keys
    keys = keys.map(&:to_s)
    keys = keys.map {|k| k.sub(/\?$/, "")}
    keys.map(&:to_sym)
  end

  def initialize_observation_filters_for_rss_log
    conds = obs_filter_sql_conds
    return if conds.empty?

    # and_clause splat wraps a single arg in an array; so if only 1 condition,
    # call and_clause with a string (rather than 1-element array).
    conds = conds.first if conds.size == 1
    @where << "observations.id IS NULL OR (#{and_clause(conds)})"
  end

  def initialize_observation_filters
    @where += obs_filter_sql_conds
  end

  # array of literal sql conditions to be included in query
  def obs_filter_sql_conds
    observation_filter_keys.each_with_object([]) do |filter_sym, conds|
      filter = eval(filter_sym.to_s)
      if filter[:on_vals].include?(params[filter_sym])
        conds << filter[:sql_cond]
      end
    end
  end
end

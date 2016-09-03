module Query::Initializers::ObservationFilters
  def observation_filter_parameter_declarations
    {
      has_images?:   :string,
      has_specimen?: :string
    }
  end

  def has_images
    {
      checked_val:  "NOT NULL",           # value when checkbox checked
      off_val:      "off",                # filter is off
      on_vals:      ["NOT NULL", "NULL"], # allowed values when filter is on
      sql_cond:     "observations.thumb_image_id IS #{params[:has_images]}"
    }
  end

  def has_specimen
    {
      checked_val:  "TRUE",
      off_val:      "off",
      on_vals:      ["TRUE", "FALSE"],
      sql_cond:     "observations.specimen IS #{params[:has_specimen]}"
   }
  end

  # Lets application controller easily check if we need to apply user's content
  # filter parameters to the current query.
  def observation_filters
    true
  end

  def has_any_observation_filters?
    observation_filter_keys.any? {|k| params[k] != nil}
  end

  def any_observation_filter_is_on?
    observation_filter_keys.any? {|k| params[k] && params[k] != "off" }
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
    observation_filter_keys.each_with_object([]) do |filter_key, conds|
      filter = eval(filter_key.to_s)
      if filter[:on_vals].include?(params[filter_key])
        conds << filter[:sql_cond]
      end
    end
  end
end

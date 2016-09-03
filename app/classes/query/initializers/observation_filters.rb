module Query::Initializers::ObservationFilters
  def observation_filter_parameter_declarations
    {
      has_images?:    :string,
      has_specimens?: :string
    }
  end

  # "NOT NULL": Observation has image(s)
  # "NULL"    : Observation has no image
  # "off"     : filter is off; convenience value which persists in Query params,
  #           : but is otherwise ignored
  def has_images_value_valid?
    ["NOT NULL", "NULL"].include?(params[:has_images])
  end

  # true      : Observation has specimen(s)
  # false     : Observation has no specimen
  # "off"     : filter is off; convenience value which persists in Query params,
  #           : but is otherwise ignored
  def has_specimens_value_valid?
    ["TRUE", "FALSE"].include?(params[:has_specimens])
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
    keys = keys.map(&:to_sym)
  end

  def initialize_observation_filters_for_rss_log
    conds = observation_filter_conditions
    return if conds.empty?

    # and_clause splat wraps a single arg in an array; so if only 1 condition,
    # call and_clause with a string (rather than 1-element array).
    conds = conds.first if conds.size == 1
    @where << "observations.id IS NULL OR (#{and_clause(conds)})"
  end

  def initialize_observation_filters
    @where += observation_filter_conditions
  end

  def observation_filter_conditions
    result = []
    if has_images_value_valid?
      result << "observations.thumb_image_id IS #{params[:has_images]}"
    end

    if has_specimens_value_valid?
      result << "observations.specimen IS #{params[:has_specimens]}"
    end
    result
  end
end

module Query::Initializers::ObservationFilters
  def observation_filter_parameter_declarations
    {
      has_specimen?: :boolean,
      has_images?:   :boolean
    }
  end

  # Lets application controller easily check if we need to apply user's content
  # filter parameters to the current query.
  def observation_filters
    true
  end

  def has_any_observation_filters?
    keys = observation_filter_parameter_declarations.keys
    keys = keys.map {|k| k.sub(/\?$/, "")}
    keys.any? {|k| params[k] != nil}
  end

  def initialize_observation_filters_for_rss_log
    conds = observation_filter_conditions
    @where << "observations.id IS NULL OR (#{and_clause(conds)})"
  end

  def initialize_observation_filters
    @where += observation_filter_conditions
  end

  def observation_filter_conditions
    result = []
    if params[:has_specimen] != nil
      val = params[:has_specimen] ? "TRUE" : "FALSE"
      result << "#{prepend}observations.specimen IS #{val}"
    end
    if params[:has_images] != nil
      val = params[:has_images] ? "NOT NULL" : "NULL"
      result << "#{prepend}observations.thumb_image_id IS #{val}"
    end
    result
  end
end

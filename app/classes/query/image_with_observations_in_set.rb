class Query::ImageWithObservationsInSet < Query::Image
  include Query::Initializers::ObservationFilters

  def parameter_declarations
    super.merge(
      ids:        [Observation],
      old_title?: :string,
      old_by?:    :string
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    title_args[:observations] = params[:old_title] ||
                                :query_title_in_set.t(type: :observation)
    set = clean_id_set(params[:ids])
    add_join(:images_observations, :observations)
    self.where << "observations.id IN (#{set})"
    initialize_observation_filters
    super
  end

  def default_order
    "name"
  end
end

class Query::NameWithObservationsInSet < Query::Name
  include Query::Initializers::InSet

  def parameter_declarations
    super.merge(
      ids: [Observation],
      old_title?: :string,
      old_by?: :string,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor("observations")
    add_join("observations")
    initialize_observation_filters
    super
  end

  def default_order
    "name"
  end
end

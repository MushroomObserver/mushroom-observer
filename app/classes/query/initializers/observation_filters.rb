module Query::Initializers::ObservationFilters
  def observation_filter_parameter_declarations
    {
      has_specimen?: :boolean,
      has_images?:   :boolean
    }
  end

  def initialize_observation_filters
    initialize_model_do_boolean(:has_specimen,
                                "observations.specimen IS TRUE",
                                "observations.specimen IS FALSE"
                               )
    initialize_model_do_boolean(:has_images,
                                "observations.thumb_image_id IS NOT NULL",
                                "observations.thumb_image_id IS NULL"
                               )
  end
end

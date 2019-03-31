module Query
  # Common code for all image queries.
  class ImageBase < Query::Base
    def model
      Image
    end

    def parameter_declarations
      super.merge(
        created_at?:           [:time],
        updated_at?:           [:time],
        date?:                 [:date],
        users?:                [User],
        names?:                [:string],
        synonym_names?:        [:string],
        children_names?:       [:string],
        locations?:            [:string],
        observations?:         [Observation],
        projects?:             [:string],
        species_lists?:        [:string],
        has_observation?:      { boolean: [true] },
        size?:                 { string: Image.all_sizes - [:full_size] },
        content_types?:        [{ string: Image.all_extensions }],
        has_notes?:            :boolean,
        notes_has?:            :string,
        copyright_holder_has?: :string,
        license?:              License,
        has_votes?:            :boolean,
        quality?:              [:float],
        confidence?:           [:float],
        ok_for_export?:        :boolean
      )
    end

    def initialize_flavor
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_date(:date, :when)
      initialize_model_do_objects_by_id(:users)
      initialize_model_do_objects_by_id(
        :observations,
        "images_observations.observation_id",
        join: :images_observations
      )
      initialize_model_do_objects_by_name(
        Name, :names, "observations.name_id",
        join: { images_observations: :observations }
      )
      initialize_model_do_objects_by_name(
        Name, :synonym_names, "observations.name_id",
        filter: :synonyms,
        join: { images_observations: :observations }
      )
      initialize_model_do_objects_by_name(
        Name, :children_names, "observations.name_id",
        filter: :all_children,
        join: { images_observations: :observations }
      )
      initialize_model_do_locations(
        "observations",
        join: { images_observations: :observations }
      )
      initialize_model_do_objects_by_name(
        Project, :projects, "images_projects.project_id",
        join: :images_projects
      )
      initialize_model_do_objects_by_name(
        SpeciesList, :species_lists,
        "observations_species_lists.species_list_id",
        join: { images_observations:
                { observations: :observations_species_lists } }
      )
      add_join(:images_observations) if params[:has_observation]
      initialize_model_do_image_size
      initialize_model_do_image_types
      initialize_model_do_boolean(
        :has_notes,
        'LENGTH(COALESCE(images.notes,"")) > 0',
        'LENGTH(COALESCE(images.notes,"")) = 0'
      )
      initialize_model_do_search(:notes_has, :notes)
      initialize_model_do_search(:copyright_holder_has, :copyright_holder)
      initialize_model_do_license
      initialize_model_do_boolean(
        :has_votes,
        'LENGTH(COALESCE(images.vote_cache,"")) > 0',
        'LENGTH(COALESCE(images.vote_cache,"")) = 0'
      )
      initialize_model_do_range(:quality, :vote_cache)
      initialize_model_do_range(
        :confidence, "observations.vote_cache",
        join: { images_observations: :observations }
      )
      initialize_model_do_boolean(
        :ok_for_export,
        "images.ok_for_export IS TRUE",
        "images.ok_for_export IS FALSE"
      )
      super
    end

    def default_order
      "created_at"
    end
  end
end

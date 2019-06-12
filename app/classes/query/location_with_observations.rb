module Query
  # Locations with observations.
  class LocationWithObservations < Query::LocationBase
    include Query::Initializers::ContentFilters

    def parameter_declarations
      super.merge(
        old_by?:           :string,
        date?:             [:date],
        names?:            [:string],
        synonym_names?:    [:string],
        children_names?:   [:string],
        locations?:        [:string],
        projects?:         [:string],
        species_lists?:    [:string],
        herbaria?:         [:string],
        herbarium_records?: [:string],
        confidence?:       [:float],
        is_collection_location?: :boolean,
        has_location?:     :boolean,
        has_name?:         :boolean,
        has_comments?:     { boolean: [true] },
        has_sequences?:    { boolean: [true] },
        has_notes?:        :boolean,
        has_notes_fields?: [:string],
        notes_has?:        :string,
        comments_has?:     :string,
      ).merge(content_filter_parameter_declarations(Observation))
    end

    def initialize_flavor
      add_join(:observations)
      initialize_content_filters(Observation)
      initialize_model_do_time(:created_at, "observations.created_at")
      initialize_model_do_time(:updated_at, "observations.updated_at")
      initialize_model_do_date(:date, "observations.when")
      initialize_model_do_objects_by_id(:users, "observations.user_id")
      initialize_model_do_objects_by_name(Name, :names, "observations.name_id")
      initialize_model_do_objects_by_name(
        Name, :synonym_names, "observations.name_id", filter: :synonyms
      )
      initialize_model_do_objects_by_name(
        Name, :children_names, "observations.name_id", filter: :all_children
      )
      initialize_model_do_locations(:observations)
      initialize_model_do_objects_by_name(
        Project, :projects,
        "observations_projects.project_id",
        join: { observations: :observations_projects }
      )
      initialize_model_do_objects_by_name(
        SpeciesList, :species_lists,
        "observations_species_lists.species_list_id",
        join: { observations: :observations_species_lists }
      )
      initialize_model_do_objects_by_name(
        Herbarium, :herbaria,
        "herbarium_records.herbarium_id",
        join: { observations:
          { herbarium_records_observations: :herbarium_records } }
      )
      initialize_model_do_objects_by_name(
        HerbariumRecord, :herbarium_records,
        "herbarium_records_observations.herbarium_record_id",
        join: :herbarium_records_observations
      )
      initialize_model_do_range(:confidence, "observations.vote_cache")
      initialize_model_do_search(:notes_has, "observations.notes")
      initialize_model_do_boolean(
        :is_collection_location,
        "observations.is_collection_location IS TRUE",
        "observations.is_collection_location IS FALSE"
      )
      initialize_model_do_boolean(
        :has_location,
        "observations.location_id IS NOT NULL",
        "observations.location_id IS NULL"
      )
      unless params[:has_name].nil?
        genus = Name.ranks[:Genus]
        group = Name.ranks[:Group]
        initialize_model_do_boolean(
          :has_name,
          "names.rank <= #{genus} or names.rank = #{group}",
          "names.rank > #{genus} and names.rank < #{group}"
        )
        add_join({ observations: :names })
      end
      initialize_model_do_boolean(
        :has_notes,
        "observations.notes != #{escape(Observation.no_notes_persisted)}",
        "observations.notes  = #{escape(Observation.no_notes_persisted)}"
      )
      add_join({ observations: :comments }) if params[:has_comments]
      if params[:comments_has].present?
        initialize_model_do_search(
          :comments_has,
          "CONCAT(comments.summary,COALESCE(comments.comment,''))"
        )
        add_join({ observations: :comments })
      end
      add_join({ observations: :sequences }) if params[:has_sequences]
      initialize_model_do_has_notes_fields(:has_notes_fields)
      super
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :all, params_with_old_by_restored)
    end
  end
end

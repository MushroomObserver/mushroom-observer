module Query
  # Code common to all observation queries.
  class ObservationBase < Query::Base
    include Query::Initializers::ContentFilters

    def model
      Observation
    end

    def parameter_declarations
      super.merge(
        created_at?:       [:time],
        updated_at?:       [:time],
        date?:             [:date],
        users?:            [User],
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
        north?:            :float,
        south?:            :float,
        east?:             :float,
        west?:             :float
      ).merge(content_filter_parameter_declarations(Observation))
    end

    def initialize_flavor
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_date(:date, :when)
      initialize_model_do_objects_by_id(:users)
      initialize_model_do_objects_by_name(Name, :names, "observations.name_id")
      initialize_model_do_objects_by_name(
        Name, :synonym_names, "observations.name_id", filter: :synonyms
      )
      initialize_model_do_objects_by_name(
        Name, :children_names, "observations.name_id", filter: :all_children
      )
      initialize_model_do_locations
      initialize_model_do_objects_by_name(
        Project, :projects,
        "observations_projects.project_id",
        join: :observations_projects
      )
      initialize_model_do_objects_by_name(
        SpeciesList, :species_lists,
        "observations_species_lists.species_list_id",
        join: :observations_species_lists
      )
      initialize_model_do_objects_by_name(
        Herbarium, :herbaria,
        "herbarium_records.herbarium_id",
        join: { herbarium_records_observations: :herbarium_records }
      )
      initialize_model_do_objects_by_name(
        HerbariumRecord, :herbarium_records,
        "herbarium_records_observations.herbarium_record_id",
        join: :herbarium_records_observations
      )
      initialize_model_do_range(:confidence, :vote_cache)
      initialize_model_do_search(:notes_has, :notes)
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
        add_join(:names)
      end
      initialize_model_do_boolean(
        :has_notes,
        "observations.notes != #{escape(Observation.no_notes_persisted)}",
        "observations.notes  = #{escape(Observation.no_notes_persisted)}"
      )
      add_join(:comments) if params[:has_comments]
      if params[:comments_has].present?
        initialize_model_do_search(
          :comments_has,
          "CONCAT(comments.summary,COALESCE(comments.comment,''))"
        )
        add_join(:comments)
      end
      add_join(:sequences) if params[:has_sequences]
      initialize_model_do_has_notes_fields(:has_notes_fields)
      initialize_model_do_observation_bounding_box
      initialize_content_filters(Observation)
      super
    end

    def default_order
      "date"
    end
  end
end

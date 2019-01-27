module Query
  # Code common to all Sequence queries.
  class SequenceBase < Query::Base
    def model
      Sequence
    end

    def parameter_declarations
      super.merge(sequence_parameter_declarations).
        merge(observation_parameter_declarations)
    end

    def sequence_parameter_declarations
      {
        created_at?:     [:time],
        updated_at?:     [:time],
        observations?:   [Observation],
        users?:          [User],
        locus?:          [:string],
        archive?:        [:string],
        accession?:      [:string],
        locus_has?:      :string,
        accession_has?:  :string,
        notes_has?:      :string
      }
    end

    def observation_parameter_declarations
      {
        obs_date?:         [:date],
        observers?:        [User],
        names?:            [:string],
        synonym_names?:    [:string],
        children_names?:   [:string],
        locations?:        [:string],
        herbaria?:         [:string],
        herbarium_records?: [:string],
        projects?:         [:string],
        species_lists?:    [:string],
        confidence?:       [:float],
        north?:            :float,
        south?:            :float,
        east?:             :float,
        west?:             :float,
        is_collection_location?: :boolean,
        has_images?:       :boolean,
        has_name?:         :boolean,
        has_specimen?:     :boolean,
        has_obs_notes?:    :boolean,
        has_notes_fields?: [:string],
        obs_notes_has?:    :string
      }
    end

    def initialize_flavor
      initialize_sequence_filters
      initialize_observation_filters
      super
    end

    def initialize_sequence_filters
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_objects_by_id(:observations)
      initialize_model_do_objects_by_id(:users)
      # Leaving out bases because some formats allow spaces and other "garbage"
      # delimiters which could interrupt the subsequence the user is searching
      # for.  Users would probably not understand why the search fails to find
      # some sequences because of this.
      initialize_model_do_exact_match(:locus)
      initialize_model_do_exact_match(:archive)
      initialize_model_do_exact_match(:accession)
      initialize_model_do_search(:locus_has, :locus)
      initialize_model_do_search(:accession_has, :accession)
      initialize_model_do_search(:notes_has, :notes)
    end

    def initialize_observation_filters
      initialize_model_do_date(
        :obs_date, "observations.when", join: :observations
      )
      initialize_model_do_objects_by_id(
        :observers, "observations.user_id", join: :observations
      )
      initialize_model_do_objects_by_name(
        Name, :names, "observations.name_id", join: :observations
      )
      initialize_model_do_objects_by_name(
        Name, :synonym_names, "observations.name_id",
        filter: :synonyms, join: :observations
      )
      initialize_model_do_objects_by_name(
        Name, :children_names, "observations.name_id",
        filter: :all_children, join: :observations
      )
      initialize_model_do_objects_by_name(
        Location, :locations, "observations.location_id", join: :observations
      )
      initialize_model_do_objects_by_name(
        Herbarium, :herbaria,
        "herbarium_records.herbarium_id",
        join: { observations: {
          herbarium_records_observations: :herbarium_records
        } }
      )
      initialize_model_do_objects_by_name(
        HerbariumRecord, :herbarium_records,
        "herbarium_records_observations.herbarium_record_id",
        join: { observations: :herbarium_records_observations }
      )
      initialize_model_do_objects_by_name(
        Project, :projects, "observations_projects.project_id",
        join: { observations: :observations_projects }
      )
      initialize_model_do_objects_by_name(
        SpeciesList, :species_lists,
        "observations_species_lists.species_list_id",
        join: { observations: :observations_species_lists }
      )
      initialize_model_do_range(
        :confidence, "observations.vote_cache", join: :observations
      )
      initialize_model_do_observation_bounding_box
      initialize_model_do_boolean(
        :is_collection_location,
        "observations.is_collection_location IS TRUE",
        "observations.is_collection_location IS FALSE"
      )
      initialize_model_do_boolean(
        :has_images,
        "observations.thumb_image_id IS NOT NULL",
        "observations.thumb_image_id IS NULL"
      )
      initialize_model_do_boolean(
        :has_specimen,
        "observations.specimen IS TRUE",
        "observations.specimen IS FALSE"
      )
      unless params[:has_name].nil?
        genus = Name.ranks[:Genus]
        group = Name.ranks[:Group]
        initialize_model_do_boolean(
          :has_name,
          "names.rank <= #{genus} or names.rank = #{group}",
          "names.rank > #{genus} and names.rank < #{group}"
        )
        add_join(observations: :names)
      end
      initialize_model_do_boolean(
        :has_obs_notes,
        "observations.notes != #{escape(Observation.no_notes_persisted)}",
        "observations.notes  = #{escape(Observation.no_notes_persisted)}"
      )
      initialize_model_do_has_notes_fields(:has_notes_fields)
      initialize_model_do_search(:obs_notes_has, "observations.notes")
      add_join(:observations) if @where.any? { |w| w.include?("observations.")}
    end

    def default_order
      "created_at"
    end
  end
end

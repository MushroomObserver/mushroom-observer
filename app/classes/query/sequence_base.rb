module Query
  # Code common to all Sequence queries.
  class SequenceBase < Query::Base
    def model
      Sequence
    end

    def parameter_declarations
      super.merge(
        # These apply to sequence itself:
        created_at?:     [:time],
        updated_at?:     [:time],
        observations?:   [Observation],
        users?:          [User],
        locus_has?:      :string,
        archive_has?:    :string,
        accession_has?:  :string,
        notes_has?:      :string
        # These apply to parent observation:
        date?:           [:date],
        observers?:      [User],
        names?:          [:string],
        synonym_names?:  [:string],
        children_names?: [:string],
        locations?:      [:string],
        projects?:       [:string],
        species_lists?:  [:string],
        confidence?:     [:float],
        north?:          :float,
        south?:          :float,
        east?:           :float,
        west?:           :float
      )
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
      initialize_model_do_search(:locus_has, :locus)
      initialize_model_do_search(:archive_has, :archive)
      initialize_model_do_search(:accession_has, :accession)
      initialize_model_do_search(:notes_has, :notes)
    end

    def initialize_observation_filters
      initialize_model_do_date(
        :date, "observations.when", join: :observations
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
      if params[:north] || params[:south] || params[:east] || params[:west]
        add_join(observations: :locations)
      end
      initialize_model_do_bounding_box(:observation)
    end

    def default_order
      "created_at"
    end
  end
end

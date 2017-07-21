module Query
  # Code common to all observation queries.
  class ObservationBase < Query::Base
    include Query::Initializers::ContentFilters

    def model
      Observation
    end

    def parameter_declarations
      super.merge(
        created_at?:     [:time],
        updated_at?:     [:time],
        date?:           [:date],
        users?:          [User],
        names?:          [:string],
        synonym_names?:  [:string],
        children_names?: [:string],
        locations?:      [:string],
        projects?:       [:string],
        species_lists?:  [:string],
        confidence?:     [:float],
        is_col_loc?:     :boolean,
        has_location?:   :boolean,
        has_notes?:      :boolean,
        has_name?:       :boolean,
        has_comments?:   { string: [:yes] },
        notes_has?:      :string,
        comments_has?:   :string,
        north?:          :float,
        south?:          :float,
        east?:           :float,
        west?:           :float
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
        Project, :projects, "observations_projects.project_id",
        join: :observations_projects
      )
      initialize_model_do_objects_by_name(
        SpeciesList, :species_lists,
        "observations_species_lists.species_list_id",
        join: :observations_species_lists
      )
      initialize_model_do_range(:confidence, :vote_cache)
      initialize_model_do_search(:notes_has, :notes)
      initialize_model_do_boolean(
        :is_col_loc,
        "observations.is_collection_location IS TRUE",
        "observations.is_collection_location IS FALSE"
      )
      initialize_model_do_boolean(
        :has_location,
        "observations.location_id IS NOT NULL",
        "observations.location_id IS NULL"
      )
      unless params[:has_name].nil?
        id = Name.unknown.id
        initialize_model_do_boolean(
          :has_name,
          "observations.name_id != #{id}",
          "observations.name_id = #{id}"
        )
      end
      initialize_model_do_boolean(
        :has_notes,
        'observations.notes != "--- {}\n"',
        'observations.notes  = "--- {}\n"'
      )
      add_join(:comments) if params[:has_comments]
      unless params[:comments_has].blank?
        initialize_model_do_search(
          :comments_has,
          "CONCAT(comments.summary,comments.comment)"
        )
        add_join(:comments)
      end
      initialize_model_do_bounding_box(:observation)
      initialize_content_filters(Observation)
      super
    end

    def default_order
      "date"
    end
  end
end

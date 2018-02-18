module Query
  # Code common to all species list queries.
  class SpeciesListBase < Query::Base
    def model
      SpeciesList
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
        title_has?:      :string,
        has_notes?:      :boolean,
        notes_has?:      :string,
        has_comments?:   { boolean: [true] },
        comments_has?:   :string
      )
    end

    def initialize_flavor
      initialize_model_do_time(:created_at)
      initialize_model_do_time(:updated_at)
      initialize_model_do_date(:date, :when)
      initialize_model_do_objects_by_id(:users)
      initialize_model_do_objects_by_name(
        Name, :names, "observations.name_id",
        join: { observations_species_lists: :observations }
      )
      initialize_model_do_objects_by_name(
        Name, :synonym_names, "observations.name_id",
        filter: :synonyms,
        join: { observations_species_lists: :observations }
      )
      initialize_model_do_objects_by_name(
        Name, :children_names, "observations.name_id",
        filter: :all_children,
        join: { observations_species_lists: :observations }
      )
      initialize_model_do_locations
      initialize_model_do_objects_by_name(
        Project, :projects, "projects_species_lists.project_id",
        join: :projects_species_lists
      )
      initialize_model_do_search(:title_has, :title)
      initialize_model_do_search(:notes_has, :notes)
      initialize_model_do_boolean(
        :has_notes,
        'LENGTH(COALESCE(species_lists.notes,"")) > 0',
        'LENGTH(COALESCE(species_lists.notes,"")) = 0'
      )
      add_join(:comments) if params[:has_comments]
      if params[:comments_has].present?
        initialize_model_do_search(
          :comments_has,
          "CONCAT(comments.summary,COALESCE(comments.comment,''))"
        )
        add_join(:comments)
      end
      super
    end

    def default_order
      "title"
    end
  end
end

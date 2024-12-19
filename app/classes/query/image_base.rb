# frozen_string_literal: true

module Query
  # base class for all flavors of Query which return Images
  class ImageBase < Query::Base
    include Query::Initializers::Names

    def model
      Image
    end

    def parameter_declarations
      super.merge(
        created_at?: [:time],
        updated_at?: [:time],
        date?: [:date],
        ids?: [Image],
        by_user?: User,
        users?: [User],
        locations?: [:string],
        observations?: [Observation],
        project?: Project,
        projects?: [:string],
        species_lists?: [:string],
        with_observation?: { boolean: [true] },
        size?: { string: Image::ALL_SIZES - [:full_size] },
        content_types?: [{ string: Image::ALL_EXTENSIONS }],
        with_notes?: :boolean,
        notes_has?: :string,
        copyright_holder_has?: :string,
        license?: [License],
        with_votes?: :boolean,
        quality?: [:float],
        confidence?: [:float],
        ok_for_export?: :boolean,
        pattern?: :string
      ).merge(names_parameter_declarations)
    end

    def initialize_flavor
      super
      unless is_a?(Query::ImageWithObservations)
        add_ids_condition("images")
        add_owner_and_time_stamp_conditions("images")
        add_by_user_condition("images")
        add_date_condition("images.when", params[:date])
        add_join(:observation_images) if params[:with_observation]
        initialize_notes_parameters
      end
      # add_by_user_condition("images")
      # add_ids_condition
      add_pattern_condition
      initialize_association_parameters
      initialize_name_parameters(:observation_images, :observations)
      initialize_image_parameters
      initialize_vote_parameters
    end

    def initialize_notes_parameters
      add_boolean_condition("LENGTH(COALESCE(images.notes,'')) > 0",
                            "LENGTH(COALESCE(images.notes,'')) = 0",
                            params[:with_notes])
      add_search_condition("images.notes", params[:notes_has])
    end

    def initialize_association_parameters
      add_id_condition("observation_images.observation_id",
                       params[:observations], :observation_images)
      add_where_condition("observations", params[:locations],
                          :observation_images, :observations)
      add_project_conditions
      add_id_condition(
        "species_list_observations.species_list_id",
        lookup_species_lists_by_name(params[:species_lists]),
        :observation_images, :observations, :species_list_observations
      )
      add_id_condition("images.license_id", params[:license])
    end

    def add_project_conditions
      add_for_project_condition
      add_id_condition("project_images.project_id",
                       lookup_projects_by_name(params[:projects]),
                       :project_images)
    end

    def add_for_project_condition
      return if params[:project].blank?

      project = find_cached_parameter_instance(Project, :project)
      @title_tag = :query_title_for_project
      @title_args[:project] = project.title
      where << "project_images.project_id = '#{project.id}'"
      add_join(:project_images)
    end

    def initialize_image_parameters
      add_search_condition("images.copyright_holder",
                           params[:copyright_holder_has])
      add_image_size_condition(params[:size])
      add_image_type_condition(params[:content_types])
      add_boolean_condition(
        "images.ok_for_export IS TRUE",
        "images.ok_for_export IS FALSE",
        params[:ok_for_export]
      )
    end

    def initialize_vote_parameters
      add_boolean_condition("images.vote_cache IS NOT NULL",
                            "images.vote_cache IS NULL",
                            params[:with_votes])
      add_range_condition("images.vote_cache", params[:quality])
      add_range_condition("observations.vote_cache", params[:confidence],
                          :observation_images, :observations)
    end

    def add_pattern_condition
      return if params[:pattern].blank?

      add_join(:observation_images, :observations)
      add_join(:observations, :locations!)
      add_join(:observations, :names)
      super
    end

    def search_fields
      "CONCAT(" \
        "names.search_name," \
        "COALESCE(images.original_name,'')," \
        "COALESCE(images.copyright_holder,'')," \
        "COALESCE(images.notes,'')," \
        "observations.where" \
        ")"
    end

    def self.default_order
      "created_at"
    end
  end
end

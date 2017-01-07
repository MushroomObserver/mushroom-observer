module Query
  # Images with observations attached to a given project.
  class ImageWithObservationsForProject < Query::ImageBase
    include Query::Initializers::ObservationFilters

    def parameter_declarations
      super.merge(
        project: Project,
        old_by?: :string
      ).merge(observation_filter_parameter_declarations)
    end

    def initialize_flavor
      project = find_cached_parameter_instance(Project, :project)
      title_args[:project] = project.title
      add_join(:images_observations, :observations)
      add_join(:observations, :observations_projects)
      where << "observations_projects.project_id = '#{project.id}'"
      initialize_observation_filters
      super
    end

    def default_order
      "name"
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :for_project, params_with_old_by_restored)
    end
  end
end

module Query
  # Locations with observations attached to a given project.
  class LocationWithObservationsForProject < LocationWithObservations
    include Query::Initializers::ContentFilters

    def parameter_declarations
      super.merge(
        project: Project
      )
    end

    def initialize_flavor
      project = find_cached_parameter_instance(Project, :project)
      title_args[:project] = project.title
      add_join(:observations, :observations_projects)
      where << "observations_projects.project_id = '#{project.id}'"
      where << "observations.is_collection_location IS TRUE"
      initialize_content_filters(Observation)
      super
    end

    def coerce_into_observation_query
      Query.lookup(:Observation, :for_project, params_with_old_by_restored)
    end
  end
end

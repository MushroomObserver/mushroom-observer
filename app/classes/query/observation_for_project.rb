# Observations attached to a given project
class Query::ObservationForProject < Query::ObservationBase
  def parameter_declarations
    super.merge(
      project: Project
    )
  end

  def initialize_flavor
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    self.where << "observations_projects.project_id = '#{project.id}'"
    add_join("observations_projects")
    super
  end

  def coerce_into_image_query
    Query.lookup(:Image, :with_observations_for_project, params)
  end

  def coerce_into_location_query
    Query.lookup(:Location, :with_observations_for_project, params)
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_observations_for_project, params)
  end
end

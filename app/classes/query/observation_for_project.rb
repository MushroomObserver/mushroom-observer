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
end

class Query::ObservationForProject < Query::Observation
  def parameter_declarations
    super.merge(
      project: Project
    )
  end

  def initialize
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    self.where << "observations_projects.project_id = '#{project.id}'"
    add_join("observations_projects")
    super
  end
end

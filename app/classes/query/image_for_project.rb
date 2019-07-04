class Query::ImageForProject < Query::ImageBase
  def parameter_declarations
    super.merge(
      project: Project
    )
  end

  def initialize_flavor
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    where << "images_projects.project_id = '#{project.id}'"
    add_join(:images_projects)
    super
  end
end

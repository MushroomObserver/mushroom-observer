class Query::SpeciesListForProject < Query::SpeciesList
  def parameter_declarations
    super.merge(
      project: Project
    )
  end

  def initialize_flavor
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    self.where << "species_lists_projects.project_id = '#{params[:project]}'"
    add_join("species_lists_projects")
    super
  end
end

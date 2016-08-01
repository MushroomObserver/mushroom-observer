class Query::NameWithObservationsForProject < Query::Name
  def parameter_declarations
    super.merge(
      project: Project,
      has_specimen?: :boolean,
      has_images?: :boolean,
      has_obs_tag?: [:string],
      has_name_tag?: [:string]
    )
  end

  def initialize_flavor
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    add_join(:observations, :observations_projects)
    self.where << "observations_projects.project_id = '#{params[:project]}'"
    initialize_observation_filters

    super
  end

  def default_order
    "name"
  end
end

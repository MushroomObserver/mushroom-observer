class Query::ImageWithObservationsForProject < Query::ImageBase
  include Query::Initializers::ObservationFilters

  def parameter_declarations
    super.merge(
      project: Project
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    add_join(:images_observations, :observations)
    add_join(:observations, :observations_projects)
    self.where << "observations_projects.project_id = '#{project.id}'"
    initialize_observation_filters
    super
  end

  def default_order
    "name"
  end
end

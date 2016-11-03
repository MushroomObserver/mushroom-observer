# Locations of (Observations attached to given Project)
# where Observation was collected at a location,
# rather than merely displayed at a location.
class Query::LocationWithObservationsForProject < Query::LocationBase
  include Query::Initializers::ObservationFilters

  def parameter_declarations
    super.merge(
      project: Project
    ).merge(observation_filter_parameter_declarations)
  end

  def initialize_flavor
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    add_join(:observations, :observations_projects)
    self.where << "observations_projects.project_id = '#{project.id}'"
    self.where << "observations.is_collection_location IS TRUE"
    initialize_observation_filters
    super
  end
end

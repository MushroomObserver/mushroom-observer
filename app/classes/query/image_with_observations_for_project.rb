# frozen_string_literal: true

class Query::ImageWithObservationsForProject < Query::ImageWithObservations
  include Query::Initializers::ContentFilters

  def parameter_declarations
    super.merge(
      project: Project
    )
  end

  def initialize_flavor
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    where << "observations_projects.project_id = '#{project.id}'"
    add_join(:images_observations, :observations)
    add_join(:observations, :observations_projects)
    super
  end

  def default_order
    "name"
  end

  def coerce_into_observation_query
    Query.lookup(:Observation, :for_project, params_with_old_by_restored)
  end
end

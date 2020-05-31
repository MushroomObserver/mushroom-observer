# frozen_string_literal: true

class Query::ObservationForProject < Query::ObservationBase
  def parameter_declarations
    super.merge(
      project: Project
    )
  end

  def initialize_flavor
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    where << "observations_projects.project_id = '#{project.id}'"
    add_join("observations_projects")
    super
  end

  def coerce_into_image_query
    do_coerce(:Image)
  end

  def coerce_into_location_query
    do_coerce(:Location)
  end

  def coerce_into_name_query
    do_coerce(:Name)
  end

  def do_coerce(new_model)
    Query.lookup(new_model, :with_observations_for_project,
                 params_plus_old_by)
  end
end

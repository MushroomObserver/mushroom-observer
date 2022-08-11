# frozen_string_literal: true

class Query::SpeciesListForProject < Query::SpeciesListBase
  def parameter_declarations
    super.merge(
      project: Project
    )
  end

  def initialize_flavor
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    where << "project_species_lists.project_id = '#{params[:project]}'"
    add_join("project_species_lists")
    super
  end
end

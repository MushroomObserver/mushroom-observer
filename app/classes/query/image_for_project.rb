# frozen_string_literal: true

class Query::ImageForProject < Query::ImageBase
  def parameter_declarations
    super.merge(
      project: Project
    )
  end

  def initialize_flavor
    project = find_cached_parameter_instance(Project, :project)
    title_args[:project] = project.title
    where << "project_images.project_id = '#{project.id}'"
    add_join(:project_images)
    super
  end
end

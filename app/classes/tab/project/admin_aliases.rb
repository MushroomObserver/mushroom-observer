# frozen_string_literal: true

class Tab::Project::AdminAliases < Tab::Base
  def initialize(project:)
    super()
    @project = project
  end

  def title
    "#{@project.aliases.count} #{:PROJECT_ALIASES.l}"
  end

  def path
    project_aliases_path(project_id: @project.id)
  end

  def alt_title
    "aliases"
  end
end

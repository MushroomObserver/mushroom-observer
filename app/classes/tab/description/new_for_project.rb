# frozen_string_literal: true

# "Create a new project-sourced description for this name/location"
# link. Used in the "Create New Draft For:" project list under the
# alt-descriptions panel.
class Tab::Description::NewForProject < Tab::Base
  def initialize(parent:, project:)
    super()
    @parent = parent
    @project = project
    @type = parent.type_tag
  end

  delegate :title, to: :@project

  def path
    send(:"new_#{@type}_description_path",
         { project: @project.id, source: "project",
           "#{@type}_id": @parent.id })
  end

  def model
    @type == :name ? NameDescription : LocationDescription
  end
end

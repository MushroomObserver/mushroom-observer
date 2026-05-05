# frozen_string_literal: true

# Renders alias management links for a project target (User or Location).
# Replaces _aliases.html.erb partial.
class Components::ProjectAliases < Components::Base
  register_output_helper :edit_project_alias_link, mark_safe: true
  register_output_helper :new_project_alias_link, mark_safe: true
  register_output_helper :destroy_button, mark_safe: true

  def initialize(project:, target:)
    super()
    @project = project
    @target = target
  end

  def view_template
    div(id: "target_project_alias_#{@target.id}") do
      render_existing_aliases
      br if alias_data.any?
      new_project_alias_link(
        @project.id, @target.id, @target.class
      )
      br
    end
  end

  private

  def alias_data
    @alias_data ||= @project.alias_data(@target)
  end

  def render_existing_aliases
    alias_data.each do |name, id|
      edit_project_alias_link(@project.id, name, id)
      destroy_button(
        target: project_alias_path(
          project_id: @project.id, id: id
        ),
        icon: :delete
      )
      br
    end
  end
end

# frozen_string_literal: true

# Per-target alias-management widget — renders existing aliases for
# a project target (User or Location) plus add/edit/destroy links.
# Rendered from the members index, locations table, and the
# aliases turbo_stream re-render. Lives under the aliases namespace
# alongside the action views (edit, index, new, show).
module Views::Controllers::Projects::Aliases
  class Widget < Views::Base
    def initialize(project:, target:)
      super()
      @project = project
      @target = target
    end

    def view_template
      div(id: "target_project_alias_#{@target.id}") do
        render_existing_aliases
        br if alias_data.any?
        render_new_link
        br
      end
    end

    private

    def alias_data
      @alias_data ||= @project.alias_data(@target)
    end

    def render_existing_aliases
      alias_data.each do |name, id|
        render_edit_link(name, id)
        span(class: "mx-2")
        render(Components::Button::Delete.new(
                 target: project_alias_path(
                   project_id: @project.id, id: id
                 ),
                 style: nil
               ))
        br
      end
    end

    def render_edit_link(name, id)
      span(id: "project_alias_#{id}") do
        render(Components::Button::ModalToggle.new(
                 name: name,
                 target: edit_project_alias_path(
                   project_id: @project.id, id: id
                 ),
                 modal_id: "project_alias_#{id}",
                 style: nil
               ))
      end
    end

    def render_new_link
      span(id: "project_alias") do
        render(Components::Button::ModalToggle.new(
                 name: :ADD.t,
                 target: new_project_alias_path(
                   project_id: @project.id,
                   target_id: @target.id,
                   target_type: @target.class
                 ),
                 modal_id: "project_alias"
               ))
      end
    end
  end
end

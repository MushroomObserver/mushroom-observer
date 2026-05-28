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
        render(Components::CrudButton::Delete.new(
                 target: project_alias_path(
                   project_id: @project.id, id: id
                 ),
                 btn: nil
               ))
        br
      end
    end

    def render_edit_link(name, id)
      span(id: "project_alias_#{id}") do
        modal_link_to(
          "project_alias_#{id}",
          *edit_project_alias_tab(@project.id, name, id)
        )
      end
    end

    def render_new_link
      span(id: "project_alias") do
        modal_link_to(
          "project_alias",
          *new_project_alias_tab(@project.id, @target.id, @target.class)
        )
      end
    end
  end
end

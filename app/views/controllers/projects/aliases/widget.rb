# frozen_string_literal: true

# Per-target alias-management widget — renders existing aliases for
# a project target (User or Location) plus add/edit/destroy links.
# Rendered from the members index, locations table, and the
# aliases turbo_stream re-render. Lives under the aliases namespace
# alongside the action views (edit, index, new, show).
module Views::Controllers::Projects::Aliases
  class Widget < Views::Base
    prop :project, ::Project
    prop :target, _Union(::User, ::Location)

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
      alias_data.each do |project_alias|
        InlineCRUDLinks(
          target: project_alias, user: current_user, edit: false,
          extras: [edit_button(project_alias)]
        )
        br
      end
    end

    # Hand-rolled: the alias's name is this link's visible text,
    # not InlineCRUDLinks' icon-only edit.
    def edit_button(project_alias)
      Components::Button.new(
        type: :modal,
        name: project_alias.name,
        target: edit_project_alias_path(
          project_id: @project.id, id: project_alias.id
        ),
        modal_id: "project_alias_#{project_alias.id}",
        variant: :strip
      )
    end

    def render_new_link
      span(id: "project_alias") do
        Button(
          type: :modal,
          name: :add.ti,
          target: new_project_alias_path(
            project_id: @project.id,
            target_id: @target.id,
            target_type: @target.class
          ),
          modal_id: "project_alias",
          variant: :strip
        )
      end
    end
  end
end

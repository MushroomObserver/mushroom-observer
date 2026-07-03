# frozen_string_literal: true

# The project-alias index table. Rendered from
# `Views::Controllers::Projects::Aliases::Index` and from the
# turbo_stream re-render in `_target_update.erb` after a CRUD on
# any one alias.
#
# Composes via `Components::Table` in column mode; each column block
# emits the cell's content via Phlex DSL.
module Views::Controllers::Projects::Aliases
  class Table < Views::Base
    TABLE_ID = "index_project_alias_table"

    # Callers must eager-load `:target` so the per-row
    # `link_to(alias_.target.try(:format_name), alias_.target)` cell
    # doesn't trigger N+1 queries. The `Projects::AliasesController`
    # paths supply that.
    def initialize(project_aliases:)
      super()
      @project_aliases = project_aliases
    end

    def view_template
      Table(@project_aliases,
            variant: :striped, identifier: "project-members",
            class: "mt-3", id: TABLE_ID) do |t|
        t.column(:NAME.t) { |a| plain(a.name) }
        t.column(:TARGET_TYPE.t) { |a| plain(a.target_type) }
        t.column(:TARGET.t) { |a| render_target_cell(a) }
        t.column(:ACTIONS.t) { |a| render_actions_cell(a) }
      end
    end

    private

    def render_target_cell(alias_)
      link_to(alias_.target.try(:format_name), alias_.target)
    end

    def render_actions_cell(alias_)
      render(Components::Button.new(
               type: :edit,
               target: edit_project_alias_path(
                 project_id: alias_.project_id, id: alias_.id
               ),
               name: :edit_object.t(type: :project_alias),
               variant: :strip
             ))
      span(class: "mx-2")
      render(Components::Button.new(
               type: :delete,
               target: project_alias_path(
                 project_id: alias_.project_id, id: alias_.id
               ),
               variant: :strip
             ))
    end
  end
end

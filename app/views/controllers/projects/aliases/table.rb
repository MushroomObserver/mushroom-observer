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
    # `Link(type: :get, name: ..., target: alias_.target)` cell
    # doesn't trigger N+1 queries. The `Projects::AliasesController`
    # paths supply that.
    def initialize(project_aliases:)
      super()
      @project_aliases = project_aliases
    end

    # Must stay `render(::Components::Table.new(...))`, not bare
    # `Table(...)` Kit syntax -- this view class is itself named
    # `Table`, so Kit's constant lookup would recurse into itself
    # instead of resolving Components::Table (see commit 33fdc952e5,
    # which reverted this exact call from Kit syntax back to
    # render(...) after hitting the bug).
    def view_template
      render(::Components::Table.new(
               @project_aliases,
               variant: :striped, identifier: "project-members",
               class: "mt-3", id: TABLE_ID
             )) do |t|
        t.column(:name.ti) { |a| plain(a.name) }
        t.column(:target_type.ti) { |a| plain(a.target_type) }
        t.column(:target.ti) { |a| render_target_cell(a) }
        t.column(:actions.ti) { |a| render_actions_cell(a) }
      end
    end

    private

    def render_target_cell(alias_)
      target = alias_.target
      # Target is either a User or a Location (see ProjectAlias) - only
      # Location's format_name is viewer-aware (postal/scientific).
      name = if target.is_a?(::Location)
               target.format_name(current_user)
             else
               target.try(:format_name)
             end
      Link(type: :get, name: name, target: target)
    end

    def render_actions_cell(alias_)
      Button(
        type: :edit,
        target: edit_project_alias_path(
          project_id: alias_.project_id, id: alias_.id
        ),
        name: :edit_object.t(type: :project_alias),
        variant: :strip
      )
      span(class: "mx-2")
      Button(
        type: :delete,
        target: project_alias_path(
          project_id: alias_.project_id, id: alias_.id
        ),
        variant: :strip
      )
    end
  end
end

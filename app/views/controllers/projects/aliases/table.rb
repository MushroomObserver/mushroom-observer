# frozen_string_literal: true

# The project-alias index table. Rendered from
# `Views::Controllers::Projects::Aliases::Index` and from the
# turbo_stream re-render in `_target_update.erb` after a CRUD on
# any one alias.
#
# Encapsulates the row-building (formerly `project_alias_rows`,
# `project_alias_row`, `project_alias_actions` in `ProjectsHelper`)
# so the helper module can shed the rendering concerns.
module Views::Controllers::Projects::Aliases
  class Table < Views::Base
    TABLE_ID = "index_project_alias_table"
    TABLE_CLASS = "table table-striped table-project-members mt-3"

    def initialize(project_aliases:)
      super()
      @project_aliases = project_aliases.includes(:target)
    end

    def view_template
      make_table(
        headers: column_headers,
        rows: alias_rows,
        table_opts: { class: TABLE_CLASS, id: TABLE_ID }
      )
    end

    private

    def column_headers
      [:NAME.t, :TARGET_TYPE.t, :TARGET.t, :ACTIONS.t]
    end

    def alias_rows
      @project_aliases.map { |alias_| build_row(alias_) }
    end

    def build_row(alias_)
      [
        alias_.name,
        alias_.target_type,
        target_cell(alias_),
        actions_cell(alias_)
      ]
    end

    # In Phlex, `link_to` is an output helper — it emits to the
    # current buffer rather than returning a string. `make_table`
    # expects each cell to be a complete value/SafeBuffer, so we
    # `capture` the link emission into a buffer to use as the cell.
    def target_cell(alias_)
      capture do
        link_to(alias_.target.try(:format_name), alias_.target)
      end
    end

    # `make_table` joins row cells with `safe_join`, so each cell
    # needs to be a single SafeBuffer. `capture` collects the emitted
    # edit/destroy buttons (and the spacer span between them) into
    # one buffer.
    def actions_cell(alias_)
      capture do
        render(Components::CrudButton::Edit.new(
                 target: edit_project_alias_path(
                   project_id: alias_.project_id, id: alias_.id
                 ),
                 name: :edit_object.t(type: :project_alias),
                 btn: nil
               ))
        span(class: "mx-2")
        render(Components::CrudButton::Delete.new(
                 target: project_alias_path(
                   project_id: alias_.project_id, id: alias_.id
                 ),
                 btn: nil
               ))
      end
    end
  end
end

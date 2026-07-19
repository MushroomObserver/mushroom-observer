# frozen_string_literal: true

module Views::Controllers::InatImports
  # Table of iNat imports. Admins see all imports; regular users see their own.
  class Index < Views::FullPageBase
    prop :imports, _Array(::InatImport)
    prop :admin, _Boolean, default: false
    # Ids of imports that have linked observations; only these get a
    # Results link (historic imports predate the link — see the controller).
    prop :result_import_ids, _Array(::Integer), default: -> { [] }

    def view_template
      container_class(:wide)
      add_page_title(:inat_imports_index_title.l)
      add_context_nav(Tab::InatImport::Actions.new(include_index: false))
      Table(@imports, class: "table-striped") do |t|
        render_columns(t)
      end
    end

    def render_columns(tbl)
      tbl.column(:inat_imports_index_when_utc.l) do |imp|
        plain(when_text(imp))
      end
      if @admin
        tbl.column(:user.ti) do |imp|
          render(Components::Link::User.new(user: imp.user))
        end
      end
      render_count_columns(tbl)
      tbl.column(:results.ti) { |imp| results_link(imp) }
      tbl.column(:reports.ti) { |imp| report_link(imp) }
    end

    def render_count_columns(tbl)
      tbl.column(:status.ti) { |imp| plain(imp.state.to_s) }
      tbl.column(:inat_import_tracker_imported_count.l) do |imp|
        plain(imp.imported_count.to_s)
      end
      tbl.column(:inat_imports_index_skipped.l) do |imp|
        plain(imp.ignored_total_count.to_s)
      end
    end

    private

    def results_link(import)
      return unless result_ids.include?(import.id)

      link_to(:results.ti, results_inat_import_path(import))
    end

    def result_ids
      @result_ids ||= @result_import_ids.to_set
    end

    def report_link(import)
      link_to(:report.ti, inat_import_path(import))
    end

    def when_text(import)
      # updated_at rather than ended_at: it's populated for in-progress
      # imports too, and matches ended_at (within seconds) once finished.
      # Shown in UTC without a timezone offset (see the "When (UTC)" header).
      import.updated_at.utc.strftime("%Y-%m-%d %H:%M:%S")
    end
  end
end

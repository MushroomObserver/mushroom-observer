# frozen_string_literal: true

module Views::Controllers::InatImports
  # Table of iNat imports. Admins see all imports; regular users see their own.
  class Index < Views::FullPageBase
    prop :imports, _Array(::InatImport)
    prop :admin, :boolean, default: false

    def view_template
      add_page_title(:inat_imports_index_title.l)
      render(Components::Table.new(@imports, class: "table-striped")) do |t|
        render_columns(t)
      end
    end

    def render_columns(tbl)
      tbl.column(:USER.t) { |imp| user_link(imp.user) } if @admin
      render_count_columns(tbl)
      tbl.column(:results.l) { |imp| results_link(imp) }
    end

    def render_count_columns(tbl)
      tbl.column(:STATUS.l) { |imp| plain(imp.state.to_s) }
      tbl.column(:inat_import_tracker_imported_count.l) do |imp|
        plain(imp.imported_count.to_s)
      end
      tbl.column(:inat_import_confirm_ignored_total_caption.l) do |imp|
        plain(imp.ignored_total_count.to_s)
      end
    end

    private

    def results_link(import)
      return unless import.Done? && import.imported_count.to_i.positive?

      link_to(:results.l, results_inat_import_path(import))
    end
  end
end

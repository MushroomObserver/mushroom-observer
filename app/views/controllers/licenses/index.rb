# frozen_string_literal: true

module Views::Controllers::Licenses
  # Licenses index — read-only list of every License row.
  class Index < Views::FullPageBase
    prop :objects, _Array(::License)

    def view_template
      container_class(:wide)
      add_page_title(:index_license_header.l)
      add_context_nav(::Tab::License::IndexActions.new)

      div { render_table }
    end

    private

    def render_table
      render(::Components::Table.new(@objects)) { |tbl| add_columns(tbl) }
    end

    def add_columns(tbl)
      tbl.column("#{:ID.l}:") { |lic| lic.id.to_s }
      tbl.column(:license_display_name.l) do |lic|
        link_to(lic.display_name, lic)
      end
      tbl.column(:license_url.l) { |lic| link_to(lic.url, lic.url) }
      tbl.column("#{:deprecated.l}?") { |lic| lic.deprecated ? "X" : "" }
    end
  end
end

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
      Table(@objects) { |tbl| add_columns(tbl) }
    end

    def add_columns(tbl)
      add_id_column(tbl)
      add_display_name_column(tbl)
      add_url_column(tbl)
      add_deprecated_column(tbl)
    end

    def add_id_column(tbl)
      tbl.column(append_colon(:id.ti)) { |lic| lic.id.to_s }
    end

    def add_display_name_column(tbl)
      tbl.column(:license_display_name.l) do |lic|
        Link(type: :get, name: lic.display_name, target: lic)
      end
    end

    def add_url_column(tbl)
      tbl.column(:license_url.l) do |lic|
        Link(type: :get, name: lic.url, target: lic.url)
      end
    end

    def add_deprecated_column(tbl)
      tbl.column("#{:deprecated.l}?") { |lic| lic.deprecated ? "X" : "" }
    end
  end
end

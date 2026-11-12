# frozen_string_literal: true

module Views::Controllers::Licenses
  # Licenses index — read-only list of every License row.
  class Index < Views::FullPageBase
    prop :objects, _Array(::License)

    def view_template
      container_class(:wide)
      add_context_nav(::Tab::License::IndexActions.new)

      div(class: "mt-3") { render_table }
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
      tbl.column(:mo_id.t) { |lic| lic.id.to_s }
    end

    def add_display_name_column(tbl)
      tbl.column(:license_display_name.t) do |lic|
        Link(type: :get, name: lic.display_name, target: lic)
      end
    end

    def add_url_column(tbl)
      tbl.column(:url.t) do |lic|
        Link(type: :get, name: lic.url, target: lic.url)
      end
    end

    def add_deprecated_column(tbl)
      tbl.column("#{:deprecated.ti}?", align: :right) do |lic|
        lic.deprecated ? "X" : ""
      end
    end
  end
end

# frozen_string_literal: true

module Views::Controllers::Licenses
  # Read-only license detail page.
  class Show < Views::FullPageBase
    prop :license, ::License

    def view_template
      render_page_chrome
      render_fields
    end

    private

    def render_page_chrome
      container_class(:text)
      add_page_title(show_title)
      add_edit_icons(@license, current_user, show_delete: !@license.in_use?)
      content_padding(:panels)
    end

    def render_fields
      Table(field_rows, variant: :striped, identifier: "license",
                        show_headers: false) do |t|
        t.column(nil) { |row| trusted_html(append_colon(row.first)) }
        t.column(nil) { |row| b { render_field_value(row.last) } }
      end
    end

    def field_rows
      [
        [:id.ti, @license.id],
        [:license_display_name.l, @license.display_name],
        [:url.l, link_to_url],
        [:deprecated.ti, @license.deprecated.to_s],
        [:created.ti, formatted_date(@license.created_at)],
        [:updated.ti, formatted_date(@license.updated_at)]
      ]
    end

    def render_field_value(value)
      if value.is_a?(::ActiveSupport::SafeBuffer)
        trusted_html(value)
      else
        plain(value.to_s)
      end
    end

    def show_title
      capture do
        IDBadge(object: @license, size: :sm)
        plain(@license.display_name)
      end
    end

    def link_to_url
      capture do
        Link(type: :external, content: @license.url,
             path: @license.url)
      end
    end

    def formatted_date(date)
      date.strftime("%Y-%m-%d %H:%M:%S")
    end
  end
end

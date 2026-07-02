# frozen_string_literal: true

module Views::Controllers::Licenses
  # Read-only license detail page.
  class Show < Views::FullPageBase
    prop :license, ::License

    def view_template
      container_class(:wide)
      add_page_title(show_title)
      add_context_nav(::Tab::License::ShowActions.new(license: @license))

      div { render_fields }
    end

    private

    def render_fields
      render_id_and_name
      labeled_field(:license_url.l, link_to_url)
      labeled_field(:DEPRECATED.l, @license.deprecated.to_s)
      render_timestamps
    end

    def render_id_and_name
      labeled_field(:ID.l, @license.id)
      labeled_field(:license_display_name.l, @license.display_name)
    end

    def render_timestamps
      labeled_field(:CREATED.l, formatted_date(@license.created_at))
      labeled_field(:UPDATED.l, formatted_date(@license.updated_at))
    end

    def show_title
      capture do
        plain(@license.display_name)
        whitespace
        span(class: "smaller") { span { "#(#{@license.id || "?"}):" } }
      end
    end

    def labeled_field(label, value)
      p do
        plain("#{label}: ")
        b { value.is_a?(::ActiveSupport::SafeBuffer) ? trusted_html(value) : plain(value.to_s) }
      end
    end

    def link_to_url
      capture do
        render(::Components::Link::External.new(
                 content: @license.url, path: @license.url
               ))
      end
    end

    def formatted_date(date)
      date.strftime("%Y-%m-%d %H:%M:%S")
    end
  end
end

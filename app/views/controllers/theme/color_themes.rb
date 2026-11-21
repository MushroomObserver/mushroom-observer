# frozen_string_literal: true

module Views::Controllers::Theme
  # Index of available color themes.
  class ColorThemes < Views::FullPageBase
    def view_template
      add_page_title(:color_themes_title.l)

      trusted_html(:color_themes_text.tp)
      p { MO.themes.each { |name| render_theme_link(name) } }
    end

    private

    def render_theme_link(name)
      Link(type: :get, name: name.underscore.to_sym.l,
           target: url_for(action: name)) do
        plain(name.underscore.to_sym.l)
      end
      br
    end
  end
end

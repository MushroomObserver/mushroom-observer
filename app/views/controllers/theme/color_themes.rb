# frozen_string_literal: true

module Views::Controllers::Theme
  # Index of available color themes.
  class ColorThemes < Views::Base
    def view_template
      add_page_title(:color_themes_title.l)

      trusted_html(:color_themes_text.tp)
      p do
        MO.themes.each do |name|
          a(href: url_for(action: name)) { plain(name.to_sym.l) }
          br
        end
      end
    end
  end
end

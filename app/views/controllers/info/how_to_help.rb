# frozen_string_literal: true

module Views::Controllers::Info
  # How-to-help / volunteer page.
  class HowToHelp < Views::Base
    KEYS = [
      :how_help_contributors, :how_help_scientists,
      :how_help_developers, :how_help_translators,
      :how_help_donors, :how_help_business_planning
    ].freeze

    def view_template
      add_page_title(:how_help_title.l)
      trusted_html(:how_help_intro.tp)

      ul(type: "none") do
        KEYS.each { |key| li { trusted_html(key.tp) } }
      end
    end
  end
end

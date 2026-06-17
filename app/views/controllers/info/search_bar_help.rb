# frozen_string_literal: true

module Views::Controllers::Info
  # Help text for the top-nav search bar — lists the available
  # pattern-search terms for Observations and Names.
  class SearchBarHelp < Views::Base
    def view_template
      add_page_title(:search_bar_help_title.l)

      trusted_html(:pattern_search_terms_help.tp)
      render_section(:OBSERVATIONS, ::PatternSearch::Observation)
      render_section(:NAMES, ::PatternSearch::Name)
    end

    private

    def render_section(label_key, pattern_class)
      p(class: "font-weight-bold") { plain("#{label_key.l} #{:SEARCHES.l}") }
      trusted_html(pattern_class.terms_help.tp)
    end
  end
end

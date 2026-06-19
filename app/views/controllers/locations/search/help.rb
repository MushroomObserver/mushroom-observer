# frozen_string_literal: true

module Views::Controllers::Locations
  module Search
    # Help text shown on the locations-search page. Lists the
    # available pattern-search terms via `PatternSearch::Location`.
    class Help < Views::Base
      def view_template
        div(id: "locations_search_help") do
          p(class: "mt-3 font-weight-bold") do
            plain("#{:LOCATIONS.l} #{:SEARCHES.l}")
          end
          trusted_html(:pattern_search_terms_help.tp)
          trusted_html(::PatternSearch::Location.terms_help.tp)
        end
      end
    end
  end
end

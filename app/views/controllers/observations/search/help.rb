# frozen_string_literal: true

# Search-bar help blurb for the observations pattern-search input.
# Replaces `_help.erb` + the one-line `show.erb` wrapper around it.
# Rendered by `Observations::SearchController#show` — both the
# `format.html` standalone page and the `format.turbo_stream`
# update of the `#search_bar_help` slot in the top-nav.
module Views::Controllers::Observations::Search
  class Help < Views::Base
    def view_template
      p(class: "mt-3 font-weight-bold") do
        plain("#{:OBSERVATIONS.t} #{:SEARCHES.t}")
      end
      trusted_html(:pattern_search_terms_help.tp)
      trusted_html(PatternSearch::Observation.terms_help.tp)
    end
  end
end

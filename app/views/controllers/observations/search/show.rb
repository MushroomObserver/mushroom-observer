# frozen_string_literal: true

# Action template for `Observations::SearchController#show`.
# Renders the search-help block inside the full page chrome. The
# `Help` sibling class is the bare fragment used by the
# turbo_stream path of the same action; `Show` is the full-page
# wrapper for the html path.
class Views::Controllers::Observations::Search::Show < Views::FullPageBase
  def view_template
    render(Help.new)
  end
end

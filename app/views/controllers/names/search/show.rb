# frozen_string_literal: true

# Action template for `Names::SearchController#show`. Renders only
# the search-help block — the result list lives elsewhere.
# Replaces the 1-line `show.erb` that just rendered the help
# partial.
class Views::Controllers::Names::Search::Show < Views::FullPageBase
  def view_template
    render(Help.new)
  end
end

# frozen_string_literal: true

# Action template for `Names::SearchController#show`. Renders only
# the search-help block — the result list lives elsewhere.
class Views::Controllers::Names::Search::Show < Views::FullPageBase
  def view_template
    render(Views::Controllers::Names::Search::Help.new)
  end
end

# frozen_string_literal: true

module Views::Controllers::Locations
  module Search
    # Shown after a pattern-search submission. Renders the `Help`
    # sibling class.
    class Show < Views::FullPageBase
      def view_template
        content_padding(:no_panels)
        render(Help.new)
      end
    end
  end
end

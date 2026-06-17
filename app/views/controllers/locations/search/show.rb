# frozen_string_literal: true

module Views::Controllers::Locations
  module Search
    # Shown after a pattern-search submission. The original `show.erb`
    # rendered a single partial; here it simply renders the `Help`
    # sibling class.
    class Show < Views::Base
      def view_template
        render(Help.new)
      end
    end
  end
end

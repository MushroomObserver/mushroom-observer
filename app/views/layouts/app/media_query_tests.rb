# frozen_string_literal: true

module Views::Layouts::App
  # Hidden breakpoint markers used by `box-resizer.js` to detect the
  # active Bootstrap 3 breakpoint at runtime:
  #
  #   document.querySelector('[data-breakpoint]:visible').dataset.breakpoint
  #
  # Remove if/when MO upgrades to Bootstrap 4 or 5.
  class MediaQueryTests < Views::Base
    BREAKPOINTS = %w[xs sm md lg].freeze

    def view_template
      div(id: "media_query_tests") do
        BREAKPOINTS.each do |bp|
          div(data: { breakpoint: bp }, class: "visible-#{bp}")
        end
      end
    end
  end
end

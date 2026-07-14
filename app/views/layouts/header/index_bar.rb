# frozen_string_literal: true

# Index-action filter caption strip, rendered between the top nav
# and the page body on index actions (and on `maps` show). Replaces
# `_index_bar.erb`. Reads two content_for slots:
#
#   - `:filters`     — set by `Views::FullPageBase#add_query_filters`,
#                      the long filter-caption HTML
#   - `:filter_help` — set by `Header#maybe_set_filter_help`, the
#                      "(filtered)" mouseover tooltip
#
# Returns early when neither slot is populated. When `:banner_image`
# is set, the `:filters` row is suppressed (banner provides its own
# context).
module Views::Layouts
  class Header::IndexBar < Views::Base
    def view_template
      return unless content_for?(:filters) || content_for?(:filter_help)

      div(class: "row") do
        Column(xs: 12) do
          div(id: "index_bar", class: "mb-2") do
            div(class: "px-3 mt-2 mb-3") do
              render_filters
              render_filter_help
            end
          end
        end
      end
    end

    private

    def render_filters
      return if content_for?(:banner_image)

      trusted_html(content_for(:filters))
    end

    def render_filter_help
      return unless content_for?(:filter_help)

      trusted_html(content_for(:filter_help))
    end
  end
end

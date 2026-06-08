# frozen_string_literal: true

# --------- Index Filters -----------------------------
#
# Public API:
#   add_query_filters(query)  # content_for(:filters)
#                               sets the filter caption HTML for
#                               `Header::IndexBar` to yield
#
# The caption HTML itself is built by
# `Views::Controllers::Application::Content::Header::IndexBar::FilterCaption`
# — a Phlex view that owns the previously-helper-resident caption
# tree (16+ methods + the four constants, including
# `SENTINEL_TYPE_TAGS` + `type_tags_to_label`). Pre-conversion this
# file was 273 lines; now it is the public-API shim that bridges
# ERB / title-helper callers into the Phlex view.
#
module Header
  module FiltersHelper
    def add_query_filters(query)
      return unless query&.params

      content_for(:filters) do
        render(
          Views::Controllers::Application::Content::
          Header::IndexBar::FilterCaption.new(query: query)
        )
      end
    end
  end
end

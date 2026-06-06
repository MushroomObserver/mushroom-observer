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
# tree (16 methods + 4 constants). Pre-conversion this file was 273
# lines; now it is the 3-line shim plus this comment.
#
module Header
  module FiltersHelper
    # `type` param sentinels (no plural form) — use `:ALL` / `:NONE`
    # directly. The `none` sentinel arises when the controller
    # sanitizes invalid type tags down to `"none"`.
    SENTINEL_TYPE_TAGS = { "all" => :ALL, "none" => :NONE }.freeze

    def add_query_filters(query)
      return unless query&.params

      content_for(:filters) do
        render(
          Views::Controllers::Application::Content::
          Header::IndexBar::FilterCaption.new(query: query)
        )
      end
    end

    # Space-separated RssLog type tag list ("species_list project") →
    # localized labels joined by ", ". Lives here (not the Phlex
    # `FilterCaption` view) so the existing `Header::FiltersHelperTest`
    # keeps covering the SENTINEL_TYPE_TAGS branches.
    def type_tags_to_label(val)
      val.split.map do |tag|
        (SENTINEL_TYPE_TAGS[tag] || tag.pluralize.upcase.to_sym).t
      end.join(", ")
    end
  end
end

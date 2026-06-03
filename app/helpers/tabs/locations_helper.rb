# frozen_string_literal: true

module Tabs
  module LocationsHelper
    # All tab definitions migrated to PORO classes under
    # `app/classes/tab/location/*.rb` and callers sweep them
    # directly. The non-tab `locations_index_sorts` utility below
    # remains here pending relocation to
    # `app/helpers/locations_helper.rb`.

    def locations_index_sorts(query: nil)
      rss_log = query&.params&.dig(:order_by) == :rss_log
      [
        ["name", :sort_by_name.t],
        ["created_at", :sort_by_created_at.t],
        [(rss_log ? "rss_log" : "updated_at"), :sort_by_updated_at.t],
        ["num_views", :sort_by_num_views.t],
        ["box_area", :sort_by_box_area.t]
      ]
    end
  end
end

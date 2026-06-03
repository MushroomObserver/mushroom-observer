# frozen_string_literal: true

module Tabs
  module NamesHelper
    # All tab definitions migrated to PORO classes under
    # `app/classes/tab/name/*.rb`. The non-tab `names_index_sorts`
    # utility below remains here pending relocation to
    # `app/helpers/names_helper.rb`.

    def names_index_sorts(query: nil)
      rss_log = query&.params&.dig(:order_by) == :rss_log
      [
        ["name", :sort_by_name.t],
        ["created_at", :sort_by_created_at.t],
        [(rss_log ? "rss_log" : "updated_at"), :sort_by_updated_at.t],
        ["num_views", :sort_by_num_views.t]
      ]
    end
  end
end

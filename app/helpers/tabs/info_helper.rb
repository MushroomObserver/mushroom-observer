# frozen_string_literal: true

module Tabs
  module InfoHelper
    def info_site_stats_tabs
      [
        site_contributors_tab,
        site_checklist_tab
      ]
    end
  end
end

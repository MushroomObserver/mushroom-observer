# frozen_string_literal: true

module Tabs
  module ContributorsHelper
    def contributors_index_tabs
      [info_site_stats_tab]
    end

    def info_site_stats_tab
      [:app_site_stats.t, info_site_stats_path,
       { class: tab_id(__method__.to_s) }]
    end

    def site_contributors_tab
      [:app_contributors.t, contributors_path,
       { class: tab_id(__method__.to_s) }]
    end
  end
end

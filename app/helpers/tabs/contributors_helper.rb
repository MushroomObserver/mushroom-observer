# frozen_string_literal: true

module Tabs
  module ContributorsHelper
    def contributors_index_links
      [info_site_stats_link]
    end

    def info_site_stats_link
      [:app_site_stats.t, info_site_stats_path,
       { class: __method__.to_s }]
    end

    def site_contributors_link
      [:app_contributors.t, contributors_path,
       { class: __method__.to_s }]
    end
  end
end

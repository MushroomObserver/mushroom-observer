# frozen_string_literal: true

module Tabs
  module ContributorsHelper
    def contributors_index_tabs
      [info_site_stats_tab]
    end

    def info_site_stats_tab
      InternalLink.new(
        :app_site_stats.t, info_site_stats_path
      ).tab
    end

    def site_contributors_tab
      InternalLink.new(
        :app_contributors.t, contributors_path
      ).tab
    end
  end
end

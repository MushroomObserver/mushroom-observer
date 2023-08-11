# frozen_string_literal: true

module Tabs
  module ContributorsHelper
    def contributors_index_links
      [[:app_site_stats.t, info_site_stats_path,
        { class: "info_site_stats_link" }]]
    end
  end
end

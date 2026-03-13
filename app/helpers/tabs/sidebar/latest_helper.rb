# frozen_string_literal: true

module Tabs
  module Sidebar
    module LatestHelper
      def sidebar_latest_tabs(user)
        [
          nav_latest_news_tab,
          nav_latest_changes_tab(user),
          nav_latest_images_tab(user),
          nav_latest_comments_tab(user)
        ]
      end

      def nav_latest_news_tab
        InternalLink.new(:NEWS.t, articles_path,
                         html_options: { id: "nav_articles_link" }).tab
      end

      def nav_latest_changes_tab(user)
        return unless user

        InternalLink.new(:app_latest_changes.t, activity_logs_path,
                         html_options: { id: "nav_activity_logs_link" }).tab
      end

      def nav_latest_images_tab(user)
        return unless user

        InternalLink.new(:app_newest_images.t, images_path,
                         html_options: { id: "nav_images_link" }).tab
      end

      def nav_latest_comments_tab(user)
        return unless user

        InternalLink.new(:app_comments.t, comments_path,
                         html_options: { id: "nav_comments_link" }).tab
      end
    end
  end
end

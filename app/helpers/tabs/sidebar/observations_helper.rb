# frozen_string_literal: true

module Tabs
  module Sidebar
    module ObservationsHelper
      def sidebar_observations_tabs(user)
        [
          nav_latest_observations_tab,
          nav_new_observation_tab(user),
          nav_your_observations_tab(user),
          nav_identify_observations_tab(user)
        ]
      end

      def nav_latest_observations_tab
        InternalLink.new(:app_latest.t, root_path,
                         html_options: { id: "nav_observations_link" }).tab
      end

      def nav_new_observation_tab(user)
        return unless user

        InternalLink.new(:app_create_observation.t, new_observation_path,
                         html_options: { id: "nav_new_observation_link" }).tab
      end

      def nav_your_observations_tab(user)
        return unless user

        InternalLink.new(:app_your_observations.t,
                         observations_path(by_user: user.id),
                         html_options: { id: "nav_your_observations_link" }).tab
      end

      def nav_identify_observations_tab(user)
        return unless user

        InternalLink.new(
          :app_help_id_obs.t, identify_observations_path,
          html_options: { id: "nav_identify_observations_link" }
        ).tab
      end

      def nav_qr_code_tab(user)
        return unless user

        InternalLink.new(:app_qrcode.t, field_slips_qr_reader_new_path,
                         html_options: { id: "nav_qr_code_link" }).tab
      end
    end
  end
end

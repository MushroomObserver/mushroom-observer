# frozen_string_literal: true

module Components
  module Sidebar
    # Renders the user section of the sidebar for logged-in users (mobile only)
    #
    # @example Basic usage
    #   render(Components::Sidebar::User.new(
    #     user: current_user,
    #     classes: sidebar_css_classes,
    #     in_admin_mode: in_admin_mode?
    #   ))
    #
    class User < Components::Base
      include Tabs::Sidebar::UserHelper
      include Tabs::AccountHelper
      include Tabs::UsersHelper
      include Rails.application.routes.url_helpers

      prop :user, ::User
      prop :classes, _Hash(Symbol, String)
      prop :in_admin_mode, _Nilable(_Boolean), default: false

      register_output_helper :active_link_to

      def view_template
        render_heading
        render_logout_button
        render_tabs
        render_admin_button if show_admin_button?
      end

      private

      def render_heading
        div(class: class_names(@classes[:heading], @classes[:mobile_only])) do
          i(class: "glyphicon glyphicon-user")
          span(class: "ml-2") { plain(@user.login) }
        end
      end

      def render_logout_button
        trusted_html(
          button_to(
            :app_logout.t,
            account_logout_path,
            class: class_names(
              "btn btn-link",
              @classes[:indent],
              @classes[:mobile_only]
            ),
            id: "nav_user_logout_link"
          )
        )
      end

      def render_tabs
        sidebar_user_tabs(@user).compact.each do |link|
          render_nav_link(link)
        end
      end

      def render_nav_link(link)
        title, url, html_options = link
        html_options ||= {}
        html_options[:class] = class_names(
          @classes[:indent],
          @classes[:mobile_only],
          html_options[:class]
        )

        active_link_to(title, url, **html_options)
      end

      def render_admin_button
        trusted_html(
          button_to(
            :app_turn_admin_on.t,
            admin_mode_path(turn_on: true),
            class: class_names(
              "btn btn-link",
              @classes[:indent],
              @classes[:mobile_only]
            ),
            id: "nav_mobile_admin_link"
          )
        )
      end

      def show_admin_button?
        @user.admin && !@in_admin_mode.present?
      end
    end
  end
end

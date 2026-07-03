# frozen_string_literal: true

class Views::Layouts::Sidebar
  # Renders the user section of the sidebar for logged-in users
  # (mobile only).
  #
  # @example Basic usage
  #   render(Views::Layouts::Sidebar::User.new(
  #     user: @user,
  #     classes: Views::Layouts::Sidebar::CSS_CLASSES,
  #     in_admin_mode: in_admin_mode?
  #   ))
  class User < ::Components::Base
    include Rails.application.routes.url_helpers

    prop :user, ::User
    prop :classes, _Hash(Symbol, String)

    def view_template
      render_heading
      render_logout_button
      render_tabs
      render_admin_button if show_admin_button?
    end

    private

    def render_heading
      div(class: class_names(@classes[:heading], @classes[:mobile_only])) do
        render(::Components::Icon.new(type: :user))
        span(class: "ml-2") { plain(@user.login) }
      end
    end

    def render_logout_button
      Button(
        type: :post,
        name: :app_logout.t,
        target: account_logout_path,
        variant: :btn_link,
        id: "nav_user_logout_link",
        class: class_names(@classes[:indent], @classes[:mobile_only])
      )
    end

    def render_tabs
      Tab::Sidebar::UserActions.new(user: @user).filter_map(&:to_a).
        each do |link|
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

      Link(type: :active,
           content: title, path: url, **html_options)
    end

    def render_admin_button
      Button(
        type: :post,
        name: :app_turn_admin_on.t,
        target: admin_mode_path(turn_on: true),
        variant: :btn_link,
        id: "nav_mobile_admin_link",
        class: class_names(@classes[:indent], @classes[:mobile_only])
      )
    end

    def show_admin_button?
      @user.admin && !in_admin_mode?
    end
  end
end

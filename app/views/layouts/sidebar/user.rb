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

    # Logging out changes the session's theme/asset state, so Turbo
    # Drive's head-merging on the redirected page can corrupt
    # stylesheets. `Tab::UserNav::Logout` already opts out of Turbo
    # for this reason — source everything from it instead of
    # re-typing the title/path/opt-out (this is also what the desktop
    # user-nav dropdown renders).
    def render_logout_button
      tab = Tab::UserNav::Logout.new
      Button(
        type: :post,
        name: tab.title,
        target: tab.path,
        variant: :btn_link,
        class: class_names(@classes[:indent], @classes[:mobile_only],
                           tab.html_options[:class]),
        data: tab.html_options[:data]
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

    # Toggling admin mode changes the session's theme/asset state, so
    # Turbo Drive's head-merging on the redirected page can corrupt
    # stylesheets. `Tab::UserNav::AdminMode` already opts out of
    # Turbo for this reason — source everything from it instead of
    # re-typing the title/path/opt-out (this is also what the desktop
    # user-nav dropdown renders).
    def render_admin_button
      tab = Tab::UserNav::AdminMode.new(in_admin_mode: false)
      Button(
        type: :post,
        name: tab.title,
        target: tab.path,
        variant: :btn_link,
        class: class_names(@classes[:indent], @classes[:mobile_only],
                           tab.html_options[:class]),
        data: tab.html_options[:data]
      )
    end

    def show_admin_button?
      @user.admin && !in_admin_mode?
    end
  end
end

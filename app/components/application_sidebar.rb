# frozen_string_literal: true

module Components
  # Renders the main application sidebar with navigation and user controls
  #
  # @example Basic usage in layout
  #   <%= render(Components::ApplicationSidebar.new(
  #     user: @user,
  #     browser: browser,
  #     request: request,
  #     in_admin_mode: in_admin_mode?
  #   )) %>
  #
  class ApplicationSidebar < Base
    include SidebarHelper
    include Tabs::Sidebar::AdminHelper
    include Tabs::Sidebar::IndexesHelper
    include Tabs::Sidebar::InfoHelper
    include Tabs::Sidebar::LatestHelper
    include Tabs::Sidebar::LoginHelper
    include Tabs::Sidebar::ObservationsHelper
    include Tabs::Sidebar::SpeciesListsHelper

    prop :user, _Nilable(::User), default: nil
    prop :browser, _Any
    prop :request, _Any
    prop :in_admin_mode, _Nilable(_Boolean), default: false

    register_value_helper :content_for

    def view_template
      nav(id: "sidebar",
          class: "sidebar-offcanvas col-xs-8 col-sm-2 hidden-print") do
        comment { "SIDEBAR LOGO AND NAVIGATION" }
        div(id: "navigation") do
          render_logo
          div(class: classes[:wrapper], data_controller: "nav-active") do
            render_top_section
            render_context_nav_mobile if @user
            render_user_sections
            render_info_sections
          end
        end
        comment { "/SIDEBAR LOGO AND NAVIGATION" }
      end
    end

    private

    def classes
      @classes ||= sidebar_css_classes
    end

    def render_logo
      a(id: "logo_link", href: logo_href) do
        img(
          class: "logo-trim img-responsive py-10px",
          alt: "Mushroom Observer Logo",
          src: "/logo-trim.png"
        )
      end
      comment { "#logo_link" }
    end

    def logo_href
      @browser.bot? ? "/sitemap/index.html" : "/"
    end

    def render_top_section
      # This cache depends only on user status (logged-in? admin?)
      cache([user_status_string(@user), "login"]) do
        if @in_admin_mode
          render(Components::Sidebar::Admin.new(
                   heading_key: :app_admin,
                   tabs: sidebar_admin_tabs,
                   classes: classes
                 ))
        elsif @user.nil?
          render(Components::Sidebar::Login.new(
                   heading_key: :app_account,
                   tabs: sidebar_login_tabs,
                   classes: classes
                 ))
        end
      end
    end

    def render_context_nav_mobile
      # Output any content_for :context_nav_mobile
      context_nav = content_for(:context_nav_mobile)
      trusted_html(context_nav) if context_nav.present?
    end

    def render_user_sections
      # If caching obs/spl, this should be keyed for both User and QueryRecord
      # (i.e. cache invalidated if query record updated, or new ID).
      # cache([@user, current_query_record]) do
      if @user
        render(Components::Sidebar::User.new(
                 user: @user,
                 classes: classes,
                 in_admin_mode: @in_admin_mode
               ))
      end

      render(Components::Sidebar::Section.new(
               heading_key: :app_observations_left,
               tabs: sidebar_observations_tabs(@user),
               classes: classes
             ))

      return unless @user

      render(Components::Sidebar::Section.new(
               heading_key: :app_species_list,
               tabs: sidebar_species_lists_tabs(@user),
               classes: classes
             ))

      # end
    end

    def render_info_sections
      # This cache depends only on user status (logged-in? admin?)
      cache([user_status_string(@user), "links"]) do
        render(Components::Sidebar::Section.new(
                 heading_key: :app_latest,
                 tabs: sidebar_latest_tabs(@user),
                 classes: classes
               ))

        if @user
          render(Components::Sidebar::Section.new(
                   heading_key: :INDEXES,
                   tabs: sidebar_indexes_tabs,
                   classes: classes
                 ))
        end

        render(Components::Sidebar::Section.new(
                 heading_key: :app_more,
                 tabs: sidebar_info_tabs,
                 classes: classes
               ))

        render_languages_section
      end
    end

    def render_languages_section
      return if @browser.bot?

      render(Components::Sidebar::Languages.new(
               browser: @browser,
               request: @request
             ))
    end

    def user_status_string(user = nil)
      if @in_admin_mode
        "admin_mode"
      elsif @browser.bot?
        "robot"
      elsif !user.nil?
        "user"
      else
        "guest"
      end
    end
  end
end

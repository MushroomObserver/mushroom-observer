# frozen_string_literal: true

# The default application layout. `Views::FullPageBase#around_template`
# wraps every action view in this layout when `session[:layout]` is
# anything other than `"printable"`.
#
# Extends `Components::Base` directly, NOT `Views::Base`: the wrap
# lives on `Views::FullPageBase < Views::Base`, and re-entering it
# from the layout itself would recurse.
module Views::Layouts
  class Application < Components::Base
    register_value_helper :browser

    # Action-specific customizations. `Views::FullPageBase#layout_props`
    # reads these off the controller's instance variables
    # (`@canonical_url`, `@any_content_filters_applied`) and forwards
    # them into this layout's constructor; the layout itself doesn't
    # touch the controller.
    prop :canonical_url, _Nilable(::String), default: nil
    prop :any_content_filters_applied, _Nilable(_Boolean), default: nil

    def view_template(&block)
      user = current_user
      theme = css_theme(user)
      doctype
      html(class: html_class) do
        head { render_head(theme) }
        body(class: body_class(user, theme),
             data: { controller: "lazyload tooltip" }) do
          render_body(&block)
        end
      end
    end

    private

    # Picks the stylesheet bundle for this page. Admin-mode flips to
    # the admin stylesheet, sudo-mode flags itself visually; otherwise
    # `theme_for(user)` picks the user's stylesheet.
    def css_theme(user)
      return "Admin" if in_admin_mode?
      return "Sudo" if session[:real_user_id].present?

      theme_for(user)
    end

    # Bots and themeless users fall back to `MO.default_theme`; an
    # `action_name` that matches a theme name renders THAT theme (so
    # browsing a theme's info page shows the theme); a logged-in user
    # with a registered preference wins; otherwise a random theme
    # (logged-in users see the variety).
    def theme_for(user)
      return MO.default_theme if browser.bot? || !user
      return action_name if theme_matches_action?
      return user.theme if user_has_valid_theme?(user)

      MO.themes.sample
    end

    def theme_matches_action?
      MO.themes.member?(action_name)
    end

    def user_has_valid_theme?(user)
      user.theme.present? && MO.themes.member?(user.theme)
    end

    def html_class
      Rails.env.test? ? "" : "scroll-behavior-smooth"
    end

    def render_head(theme)
      render(Views::Layouts::App::Head.new(
               css_theme: theme,
               canonical_url: @canonical_url
             ))
    end

    def render_body(&block)
      render_gtm_iframe_when_production
      render_main_container(content_classes_for_main, &block)
      render_bottom_singletons
    end

    # `content_for(:container_class)` + `(:content_padding)` are
    # guaranteed populated by the time the layout renders —
    # `Views::FullPageBase#around_template` fills any unset slot
    # with the matching default after the action's `view_template`
    # has finished.
    def content_classes_for_main
      class_names(content_for(:container_class),
                  content_for(:content_padding))
    end

    def render_main_container(content_classes, &block)
      div(id: "main_container", class: "px-sm-3",
          data: { controller: "nav links", nav_target: "container" }) do
        render(Views::Layouts::App::Banners.new)
        div(class: "row row-offcanvas row-offcanvas-left",
            data: { nav_target: "offcanvas" }) do
          render(Views::Layouts::Sidebar.new(
                   user: current_user,
                   browser: browser,
                   request: request,
                   languages: current_languages
                 ))
          render_right_side(content_classes, &block)
        end
      end
    end

    def render_right_side(content_classes, &block)
      Column(id: "right_side", xs: 12, md: 10) do
        render(Views::Layouts::TopNav.new(user: current_user,
                                          query: current_query))
        render(Views::Layouts::App::PageFlash.new)
        render(Views::Layouts::Header.new(
                 any_content_filters_applied: @any_content_filters_applied
               ))
        main(id: "content", class: content_classes,
             data: { controller: "lightgallery" }) do
          comment { "MAIN_PAGE_CONTENT" }
          yield
          comment { "/MAIN_PAGE_CONTENT" }
          render(Views::Layouts::TranslatorsCredit.new)
        end
      end
    end

    def render_gtm_iframe_when_production
      render(Views::Layouts::App::GtmIframe.new) if Rails.env.production?
    end

    def render_bottom_singletons
      Modal(type: :progress_spinner)
      Modal(type: :confirm)
      render(Views::Layouts::App::MediaQueryTests.new)
      render(Views::Layouts::App::GtmFooter.new)
    end

    # The body's class list is "what page the user is looking at" —
    # see the comment on `controller_action_class` for why `create`
    # falls through to `new` and `update` to `edit`.
    def body_class(user, theme)
      class_names(controller_action_class,
                  "theme-#{theme.underscore.dasherize}",
                  "location-format-#{user&.location_format || "postal"}",
                  user ? "logged-in-user" : "no-user")
    end

    # `create` failures fall through to `new`, `update` failures to
    # `edit`. The body class reflects "the page the user is looking
    # at" rather than "the verb that brought us here" so test
    # assertions like `assert_select("body.<thing>__new")` don't need
    # a separate variant for the re-rendered-after-validation-failure
    # path.
    def controller_action_class
      action = case controller.action_name
               when "create" then "new"
               when "update" then "edit"
               else controller.action_name
               end
      "#{controller.controller_name}__#{action}"
    end
  end
end

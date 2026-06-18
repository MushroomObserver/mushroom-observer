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
    register_value_helper :css_theme
    register_value_helper :default_container_class
    register_value_helper :default_column_classes
    register_value_helper :default_content_padding
    register_value_helper :browser
    register_value_helper :request

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

    # Side-effecting `content_for(:container_class)` /
    # `content_for(:content_padding)` defaults are populated before
    # being read back here.
    def content_classes_for_main
      default_container_class
      default_column_classes
      default_content_padding
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
      div(id: "right_side", class: "col-xs-12 col-md-10") do
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
      render(Components::Modal::ProgressSpinner.new)
      render(Components::Modal::Confirm.new)
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

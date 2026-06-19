# frozen_string_literal: true

class Views::Layouts::Sidebar
  # Renders the language dropdown in the sidebar.
  #
  # @example Basic usage
  #   render(Views::Layouts::Sidebar::Languages.new(
  #     browser: browser,
  #     request: request
  #   ))
  class Languages < ::Views::Base
    # `:browser` is unused inside this view but kept for API
    # symmetry with `Sidebar`, which threads both
    # `browser:` and `request:` through to here. Duck-typed for the
    # same reason as the parent (tests pass a Struct stub).
    prop :browser, _Interface(:bot?)
    # Used via `attr_reader :request` so `reload_with_args` (inherited
    # from `Views::Base`) can read `request.url`.
    prop :request, _Interface(:url)
    prop :languages, _Array(Language)

    # Make request available to the inherited `reload_with_args`.
    attr_reader :request

    def view_template
      div(class: "list-group-item pl-3 overflow-visible") do
        div(class: "dropdown") do
          render_dropdown_label
          render_dropdown_toggle
          render_dropdown_menu
        end
      end
    end

    private

    def render_dropdown_label
      span { plain("#{:app_languages.t}:") }
    end

    def render_dropdown_toggle
      a(
        class: "dropdown-toggle",
        role: "button",
        href: "#",
        id: "language_dropdown_toggle",
        data: { toggle: "dropdown" },
        aria: { expanded: "false" }
      ) do
        img(
          src: "/flags/flag-#{I18n.locale.downcase}.png",
          class: "lang-flag",
          alt: I18n.locale.downcase
        )
        span(class: "caret")
      end
    end

    def render_dropdown_menu
      ul(
        id: "language_dropdown_menu",
        class: "dropdown-menu",
        role: "menu"
      ) do
        @languages.each do |lang|
          render_language_item(lang)
        end
      end
    end

    def render_language_item(lang)
      li do
        a(
          href: reload_with_args(user_locale: lang.locale),
          class: "lang-dropdown-link text-nowrap",
          id: "lang_drop_#{lang.locale}_link",
          data: { locale: lang.locale }
        ) do
          img(
            src: "/flags/flag-#{lang.locale}.png",
            class: "lang-flag",
            alt: lang.locale
          )
          plain(" ")
          plain(lang.name)
        end
      end
    end
  end
end

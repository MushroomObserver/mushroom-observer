# frozen_string_literal: true

class Views::Layouts::Sidebar
  # Renders the language toggle + collapsible language list in the
  # sidebar. An inline accordion (Link::CollapseToggle + CollapseDiv),
  # not a floating dropdown — a popup menu doesn't behave well at the
  # bottom of a long nav (clipping / off-screen risk), and an inline
  # expand keeps everything in the normal document flow.
  #
  # @example Basic usage
  #   render(Views::Layouts::Sidebar::Languages.new(
  #     browser: browser,
  #     request: request
  #   ))
  class Languages < ::Views::Base
    # Regional-indicator flag emoji per locale — a deliberate mapping,
    # not a formula. ISO 639 language codes and ISO 3166 country codes
    # are different systems that only coincidentally overlap, and
    # sometimes collide misleadingly: `uk` here is Ukrainian, not "UK"
    # (which isn't even a real ISO 3166 code — Great Britain is `GB`);
    # `ar` (Arabic) has no single owning country, and ISO 3166 `AR` is
    # Argentina, unrelated to the language. Each entry is a curated
    # choice, matching the flags the old `public/flags/flag-*.png`
    # assets showed.
    FLAG_EMOJI = {
      "ar" => "🇵🇸", # Arabic — Palestine
      "be" => "🇧🇾", # Belarusian — Belarus
      "de" => "🇩🇪", # German — Germany
      "el" => "🇬🇷", # Greek — Greece
      "en" => "🇬🇧", # English — Great Britain
      "es" => "🇪🇸", # Spanish — Spain
      "fa" => "🇮🇷", # Persian/Farsi — Iran
      "fr" => "🇫🇷", # French — France
      "it" => "🇮🇹", # Italian — Italy
      "jp" => "🇯🇵", # Japanese — Japan
      "pl" => "🇵🇱", # Polish — Poland
      "pt" => "🇵🇹", # Portuguese — Portugal
      "ru" => "🇷🇺", # Russian — Russia
      "tr" => "🇹🇷", # Turkish — Turkey
      "uk" => "🇺🇦", # Ukrainian — Ukraine
      "zh" => "🇨🇳"  # Chinese — China
    }.freeze
    DEFAULT_FLAG = "🏳️"

    TOGGLE_ID = "language_dropdown_toggle"
    COLLAPSE_ID = "language_dropdown_collapse"

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
      render_toggle
      CollapseDiv(id: COLLAPSE_ID) do
        @languages.each { |lang| render_language_row(lang) }
      end
    end

    private

    # The current-locale flag + "Languages:" label IS the collapse
    # trigger — no separate toggle affordance. `panel-collapse-trigger`
    # reuses `Panel`'s established chevron-flip CSS (`.active-icon`
    # shown/hidden via the `.collapsed` class) rather than inventing a
    # new one. Standalone `ListGroup::LinkItem` (not the `ListGroup(...)
    # do |list| ... end` builder) since this is the only row rendered
    # by this view outside of any iteration.
    def render_toggle
      render(Components::ListGroup::LinkItem.new(
               class: "pl-3 panel-collapse-trigger"
             )) do |css_class|
        Link(type: :collapse_toggle, target_id: COLLAPSE_ID,
             id: TOGGLE_ID, class: css_class) do
          plain("#{:app_languages.t}:")
          whitespace
          span(class: "lang-flag-emoji") { plain(flag_for(I18n.locale)) }
          whitespace
          Icon(type: :chevron_down, title: :OPEN.l,
               html_class: "active-icon")
          Icon(type: :chevron_up, title: :CLOSE.l)
        end
      end
    end

    def render_language_row(lang)
      render(
        Components::ListGroup::LinkItem.new(class: "indent")
      ) do |css_class|
        a(href: reload_with_args(user_locale: lang.locale),
          id: "lang_drop_#{lang.locale}_link",
          class: css_class,
          data: { locale: lang.locale }) do
          span(class: "lang-flag-emoji") { plain(flag_for(lang.locale)) }
          whitespace
          plain(lang.name)
        end
      end
    end

    def flag_for(locale)
      FLAG_EMOJI.fetch(locale.to_s, DEFAULT_FLAG)
    end
  end
end

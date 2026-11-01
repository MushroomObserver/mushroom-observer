# frozen_string_literal: true

# POST button that switches the app's locale -- shared by the
# sidebar's language switcher and the translators' note page's
# beta-inclusive language list, both rendering the same flag+name
# row content. A GET link here would be a crawler/bookmark/browser-
# history replay hazard: `set_locale` reads this same `user_locale`
# param on every request (issue #5074).
#
# @example
#   LanguageSwitchButton(language: lang, id: "lang_drop_#{lang.locale}_link",
#                        class: css_class)
class Components::LanguageSwitchButton < Components::Base
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

  def self.flag_for(locale)
    FLAG_EMOJI.fetch(locale.to_s, DEFAULT_FLAG)
  end

  prop :language, ::Language
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template
    Button(
      type: :post,
      name: @language.name,
      target: switch_locale_path,
      params: { user_locale: @language.locale },
      variant: :link,
      **@attributes.except(:data),
      data: button_data
    ) { render_content }
  end

  private

  # `name:` above is required syntax but only drives CRUDBase's
  # auto-tooltip (suppressed here) -- render_content is the actual
  # visible content.
  def button_data
    (@attributes[:data] || {}).merge(tooltip_target: nil)
  end

  def render_content
    span(class: "lang-flag-emoji") do
      plain(self.class.flag_for(@language.locale))
    end
    whitespace
    plain(@language.name)
    return unless @language.beta

    whitespace
    span { plain("(beta)") }
  end
end

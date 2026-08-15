# frozen_string_literal: true

require("test_helper")

class LanguageSwitchButtonTest < ComponentTestCase
  def test_posts_to_switch_locale_path_with_user_locale_param
    html = render_button(languages(:french))

    assert_html(html,
                "form[action='#{routes.switch_locale_path}'][method='post']")
    assert_html(html,
                "form input[type='hidden']" \
                "[name='user_locale'][value='fr']")
  end

  def test_renders_flag_and_name
    lang = languages(:french)
    html = render_button(lang)

    assert_html(html, "button span.lang-flag-emoji",
                text: Components::LanguageSwitchButton::FLAG_EMOJI.fetch("fr"))
    assert_includes(html, lang.name)
  end

  def test_suppresses_auto_tooltip
    html = render_button(languages(:french))

    assert_no_html(html, "button[data-tooltip-target]")
  end

  def test_beta_language_shows_beta_label
    html = render_button(languages(:greek))

    assert_includes(html, "(beta)")
  end

  def test_non_beta_language_omits_beta_label
    html = render_button(languages(:french))

    assert_no_html(html, "button", text: /beta/)
  end

  def test_extra_html_attributes_forwarded
    html = render_button(languages(:french), id: "my_id",
                                             class: "list-group-item indent",
                                             data: { locale: "fr" })

    assert_html(html, "button#my_id.list-group-item.indent" \
                      "[data-locale='fr']")
  end

  private

  def render_button(language, **)
    render(Components::LanguageSwitchButton.new(language:, **))
  end
end

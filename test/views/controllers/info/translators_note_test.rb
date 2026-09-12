# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Info
  class TranslatorsNoteTest < ComponentTestCase
    def test_renders_language_switch_row_per_language
      french = languages(:french)
      greek = languages(:greek)
      html = render_component([french, greek])

      assert_html(html,
                  "form[action='#{routes.switch_locale_path}']" \
                  "[method='post']")
      assert_html(html,
                  "button.list-group-item[data-tooltip-target]", count: 0)
      assert_html(html,
                  "form input[type='hidden']" \
                  "[name='user_locale'][value='fr']")
      assert_includes(html, french.name)

      # Beta languages are included here (unlike the sidebar switcher,
      # which excludes them) and labeled as such.
      assert_html(html,
                  "form input[type='hidden']" \
                  "[name='user_locale'][value='el']")
      assert_includes(html, greek.name)
      assert_includes(html, "(beta)")
    end

    private

    def render_component(languages)
      render(TranslatorsNote.new(languages: languages))
    end
  end
end

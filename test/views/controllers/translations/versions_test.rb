# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Translations
  # Tests for the old-versions panel rendered by the translations UI.
  # Key coverage: `render_user_cell` branches — `login.blank?` (emits "--")
  # vs. login present (renders a user link).
  class VersionsTest < ComponentTestCase
    def setup
      super
      # `greek_one` has two versions in fixtures:
      #   v1 text="один"  author=mary (nontrivial — differs from current)
      #   v2 text="ένα"   author=dick (trivial — same as current text)
      # So `nontrivial_versions` returns [v1], authored by mary.
      @record = translation_strings(:greek_one)
      @tag = @record.tag
    end

    # When the version author's user_id is not in `user_logins` and is
    # not the current user, `render_user_cell` emits `plain("--")`.
    def test_renders_dash_when_version_author_not_in_logins
      html = render_versions(user_logins: {})

      assert_html(html, "td", text: "--".as_displayed)
    end

    # When the author's user_id IS in `user_logins`, the else branch
    # renders a `Components::Link::User` instead of "--".
    def test_renders_user_link_when_version_author_in_logins
      mary = users(:mary)
      html = render_versions(user_logins: { mary.id => mary.login })

      assert_html(html, "a[href*='/users/#{mary.id}']")
      assert_no_html(html, "td", text: "--".as_displayed)
    end

    private

    def render_versions(user_logins: {})
      render(Versions.new(
               edit_tags: [@tag],
               translated_records: { @tag => @record },
               user: users(:rolf),
               user_logins: user_logins
             ))
    end
  end
end

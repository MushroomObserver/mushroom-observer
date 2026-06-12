# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Account::Preferences
  class EditTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      User.current = @user
      @licenses = License.available_names_and_ids(@user.license)
    end

    # The Edit view is now a thin shell: page title + context nav +
    # AccountPreferencesForm. The retroactive image-pref triggers
    # (vote anonymity, license, filename purge) live inside the form
    # itself now (one per related Privacy select) — see
    # AccountPreferencesFormTest for their assertions.
    def test_renders_form
      html = render(Edit.new(user: @user, licenses: @licenses))

      assert_html(html, "form#account_preferences_form")
      # No legacy `button_to` PUT forms sitting after the main form.
      assert_no_html(html, "form[action='/images/votes/anonymity']")
      assert_no_html(html, "form[action='/images/purge_filenames']")
      assert_no_html(html, "form[action='/images/licenses/edit']")
    end
  end
end

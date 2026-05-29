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

    # The Edit view renders the AccountPreferencesForm (covered in
    # AccountPreferencesFormTest) plus three PUT buttons sitting
    # OUTSIDE the form. The PUT buttons submit to their own paths so
    # a click doesn't trip the PATCH /preferences form's autoenable.
    def test_put_buttons_render_outside_main_form
      html = render(Edit.new(user: @user, licenses: @licenses))

      assert_html(html, "form#account_preferences_form")

      # Each PUT button is a `button_to` form rendering as its own
      # `<form>` element with `_method=put`.
      ["/images/votes/anonymity",
       "/images/purge_filenames",
       "/images/licenses/edit"].each do |path|
        assert_html(html, "form[action='#{path}']")
        assert_html(html, "form[action='#{path}'] " \
                          "input[type='hidden'][name='_method'][value='put']")
      end

      # The filename-purge button carries a confirm prompt so a
      # mis-click doesn't wipe the user's filename column.
      assert_html(html, "form[action='/images/purge_filenames'] " \
                        "button[data-confirm]")
    end
  end
end

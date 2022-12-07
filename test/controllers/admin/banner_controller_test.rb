# frozen_string_literal: true

require("test_helper")

module Admin
  class BannerControllerTest < FunctionalTestCase
    def test_edit_banner
      use_test_locales do
        # Oops!  One of these tags actually exists now!
        TranslationString.where(tag: "app_banner_box").each(&:destroy)

        str1 = TranslationString.create!(
          language: languages(:english),
          tag: :app_banner_box,
          text: "old banner",
          user: User.admin
        )
        str1.update_localization

        str2 = TranslationString.create!(
          language: languages(:french),
          tag: :app_banner_box,
          text: "banner ancienne",
          user: User.admin
        )
        str2.update_localization

        get(:edit)
        assert_redirected_to(new_account_login_path)

        login("rolf")
        get(:edit)
        assert_flash_error
        assert_redirected_to("/")

        make_admin("rolf")
        get(:edit)
        assert_no_flash
        assert_response(:success)
        assert_textarea_value(:val, :app_banner_box.l)

        put(:update, params: { val: "new banner" })
        assert_no_flash
        assert_equal("new banner", :app_banner_box.l)

        strs = TranslationString.where(tag: :app_banner_box)
        strs.each do |str|
          assert_equal(
            "new banner", str.text,
            "Didn't change text of #{str.language.locale} correctly."
          )
        end
      end
    end
  end
end

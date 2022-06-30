# frozen_string_literal: true

require("test_helper")

# Controller tests for info pages
class AdminControllerTest < FunctionalTestCase
    # Prove w3c_tests renders html, with all content within the <body>
  # (and therefore without MO's layout).
  def test_w3c_tests
    login
    expect_start = "<html><head></head><body>"
    get(:w3c_tests)
    assert_equal(expect_start, @response.body[0..(expect_start.size - 1)])
  end

  def test_change_banner
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

      get(:change_banner)
      assert_redirected_to(controller: :account, action: :login)

      login("rolf")
      get(:change_banner)
      assert_flash_error
      assert_redirected_to("/")

      make_admin("rolf")
      get(:change_banner)
      assert_no_flash
      assert_response(:success)
      assert_textarea_value(:val, :app_banner_box.l)

      post(:change_banner, params: { val: "new banner" })
      assert_no_flash
      assert_redirected_to("/")
      assert_equal("new banner", :app_banner_box.l)

      strs = TranslationString.where(tag: :app_banner_box)
      strs.each do |str|
        assert_equal("new banner", str.text,
                     "Didn't change text of #{str.language.locale} correctly.")
      end
    end
  end
end

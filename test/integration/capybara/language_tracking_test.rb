# frozen_string_literal: true

require("test_helper")

class LanguageTrackingTest < CapybaraIntegrationTestCase
  # -----------------------------------------------------------------------
  #  Need integration test to make sure tags are being tracked and passed
  #  through redirects correctly.
  # -----------------------------------------------------------------------

  def test_language_tracking
    lang_session = Capybara::Session.new(:rack_test, Rails.application)
    login(mary, session: lang_session)
    mary.locale = "el"
    I18n.with_locale(:el) do
      mary.save

      TranslationString.store_localizations(
        :el,
        { test_tag1: "test_tag1 value",
          test_tag2: "test_tag2 value",
          test_flash_redirection_title: "Testing Flash Redirection" }
      )

      lang_session.visit("/test_pages/flash_redirection?tags=")
      lang_session.click_link(text: :app_edit_translations_on_page.t)
      assert_no_flash(session: lang_session)
      lang_session.assert_no_selector("span.tag", text: "test_tag1:")
      lang_session.assert_no_selector("span.tag", text: "test_tag2:")
      lang_session.assert_selector("span.tag",
                                   text: "test_flash_redirection_title:")

      lang_session.visit(
        "/test_pages/flash_redirection?tags=test_tag1,test_tag2"
      )
      lang_session.click_link(text: :app_edit_translations_on_page.t)
      assert_no_flash(session: lang_session)
      lang_session.assert_selector("span.tag", text: "test_tag1:")
      lang_session.assert_selector("span.tag", text: "test_tag2:")
      lang_session.assert_selector("span.tag",
                                   text: "test_flash_redirection_title:")
    end
  end
end

# frozen_string_literal: true

require("application_system_test_case")

class TranslationsSystemTest < ApplicationSystemTestCase
  def test_edit_translation_ajax_form
    # browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)

    use_test_locales do
      old_one = :one.l
      initial_locale = I18n.locale
      I18n.with_locale(:el) do
        greek_one = :one.l
        I18n.with_locale(initial_locale) do
          # login("rolf")
          # get(:edit, params: { locale: "en", tag: "two" })
          # visit(edit_translation_path(id: "two", locale: "en"))
          within("#translations_index") { click_link("[data-tag='two']")  }

          assert_no_flash
          # assert_response(:success)
          assert_field("input[type=submit][value=#{:SAVE.l}]", count: 1)
          assert_field("textarea[name=tag_two]", with: "two")
          assert_field("textarea[name=tag_twos]", with: "twos")
          assert_field("textarea[name=tag_TWO]", with: "Two")
          assert_field("textarea[name=tag_TWOS]", with: "Twos")

          old_one = :one.l
          # translation_for_one("en", "uno")
          within("#translations_index") { click_link("[data-tag='one']") }
          # visit(edit_translation_path(id: "one", locale: "en"))
          assert_select("locale", with: "en")
          assert_field("textarea[name=tag_one]", with: old_one)
          fill_in("textarea[name=tag_one]", with: "uno")
          within("#translation_form") { click_commit }
          assert_no_flash
          within("#translations_index") { assert_text("uno") }
          # assert_match(/locale = "en"/, @response.body)
          # assert_match(/tag = "one"/, @response.body)
          # assert_match(/str = "uno"/, @response.body)
          assert_equal("uno", :one.l)

          # get(:edit, params: { locale: "en", tag: "one" })
          visit(edit_translation_path(id: "one", locale: "en"))
          assert_no_flash
          assert_field("input[type=submit][value=#{:SAVE.l}]", count: 1)
          assert_field("textarea[name=tag_one]", with: "uno")
          fill_in("textarea[name=tag_one]", with: old_one)
          within("#translation_form") { click_commit }
          assert_equal(old_one, :one.l)

          # translation_for_one("el", "ichi")
          visit(edit_translation_path(id: "one", locale: "el"))
          fill_in("textarea[name=tag_one]", with: "ichi")
          assert_no_flash
          within("#translations_index") { assert_text("ichi") }
          # assert_match(/locale = "el"/, @response.body)
          # assert_match(/tag = "one"/, @response.body)
          # assert_match(/str = "ichi"/, @response.body)
          assert_equal("one", :one.l)

          # get(:edit, params: { locale: "el", tag: "one" })
          assert_no_flash
          assert_field("input[type=submit][value=#{:SAVE.l}]", count: 1)
          assert_field("textarea[name=tag_one]", with: "ichi")
        end
        assert_equal("ichi", :one.l)
        translation_for_one("el", greek_one)
      end
    end
  end

end

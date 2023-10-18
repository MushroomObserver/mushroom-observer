# frozen_string_literal: true

require("application_system_test_case")

class TranslationsSystemTest < ApplicationSystemTestCase
  def test_edit_translation_ajax_form
    # browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)
    visit(root_path)

    use_test_locales do
      old_one = :one.l
      initial_locale = I18n.locale

      I18n.with_locale(:fr) do
        french_one = :one.l
        # scroll_to("#language_dropdown_toggle", align: :center)
        # click_link("language_dropdown_toggle")
        # within("#language_dropdown_menu") { first("[data-locale='fr']").click }
        # assert_selector("body.observations__index")
        # binding.break
        # click_link("language_dropdown_toggle")
        # within("#language_dropdown_menu") { first("[data-locale='en']").click }
        I18n.with_locale(initial_locale) do
          # login("rolf")
          # get(:edit, params: { locale: "en", tag: "two" })
          assert_selector("#translators_credit")
          within("#translators_credit") do
            click_link("translations_index_link")
          end
          assert_selector("body.translations__index")
          # visit(edit_translation_path(id: "two", locale: "en"))
          within("#translations_index") { first("[data-tag='two']").click }

          assert_no_flash
          # assert_response(:success)
          assert_field("input[type=submit][value=#{:SAVE.l}]", count: 1)
          assert_field("textarea[name=tag_two]", with: "two")
          assert_field("textarea[name=tag_twos]", with: "twos")
          assert_field("textarea[name=tag_TWO]", with: "Two")
          assert_field("textarea[name=tag_TWOS]", with: "Twos")

          old_one = :one.l
          # translation_for_one("en", "uno")
          within("#translations_index") { first("[data-tag='one']").click }
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
          # visit(edit_translation_path(id: "one", locale: "en"))
          # assert_no_flash
          assert_field("input[type=submit][value=#{:SAVE.l}]", count: 1)
          assert_field("textarea[name=tag_one]", with: "uno")
          fill_in("textarea[name=tag_one]", with: old_one)
          within("#translation_form") { click_commit }
          assert_equal(old_one, :one.l)

          # translation_for_one("el", "ichi")
          # visit(edit_translation_path(id: "one", locale: "el"))
          select("fr", from: "locale_select")
          assert_field("textarea[name=tag_one]", with: french_one)
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
          assert_equal("ichi", :one.l)

          fill_in("textarea[name=tag_one]", with: french_one)
          within("#translation_form") { click_commit }
        end
      end
    end
  end

end

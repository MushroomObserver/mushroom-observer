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

      I18n.with_locale(:el) do
        greek_one = :one.l
        # scroll_to("#language_dropdown_toggle", align: :center)
        # click_link("language_dropdown_toggle")
        # within("#language_dropdown_menu") { first("[data-locale='fr']").click }
        # assert_selector("body.observations__index")
        # binding.break
        # click_link("language_dropdown_toggle")
        # within("#language_dropdown_menu") { first("[data-locale='en']").click }
        # binding.break
        I18n.with_locale(initial_locale) do
          assert_selector("#translators_credit")
          within("#translators_credit") do
            click_link("translations_index_link")
          end
          assert_selector("body.translations__index")
          within("#translations_index") { first("[data-tag='two']").click }

          # assert_no_flash
          assert_selector("button[type=submit]", text: :SAVE.l, count: 1)
          assert_field("tag_two", type: :textarea, with: "two")
          assert_field("tag_twos", type: :textarea, with: "twos")
          assert_field("tag_TWO", type: :textarea, with: "Two")
          assert_field("tag_TWOS", type: :textarea, with: "Twos")

          # old_one = :one.l
          within("#translations_index") { first("[data-tag='one']").click }
          assert_select("locale", selected: "English")
          assert_field("tag_one", type: :textarea, with: old_one)
          fill_in("tag_one", with: "uno")
          within("#translation_form") { click_commit }

          # assert_no_flash
          within("#translations_index") { assert_text("uno") }
          assert_equal("uno", :one.l)
          assert_selector("button[type=submit]", text: :SAVE.l, count: 1)
          assert_field("tag_one", type: :textarea, with: "uno")
          fill_in("tag_one", with: old_one)
          within("#translation_form") { click_commit }
          assert_equal(old_one, :one.l)

          select("Ελληνικά", from: "locale")
          assert_selector("#translation_form h4", text: "Ελληνικά:")
          # downcase necessary because of translation glitch, greek_one == "Ένα"
          assert_field("tag_one", type: :textarea, with: greek_one.downcase)
          fill_in("tag_one", with: "ichi")
          within("#translation_form") { click_commit }
          within("#translations_index") { assert_text("ichi") }
          # binding.break
          assert_equal("one", :one.l)

          # assert_no_flash
          assert_selector("button[type=submit]", text: :SAVE.l, count: 1)
          assert_field("tag_one", type: :textarea, with: "ichi")
          I18n.with_locale(:el) { assert_equal("ichi", :one.l) }

          fill_in("tag_one", with: greek_one.downcase)
          within("#translation_form") { click_commit }
        end
        assert_equal(greek_one.downcase, :one.l)
      end
    end
  end

end

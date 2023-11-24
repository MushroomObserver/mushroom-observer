# frozen_string_literal: true

require("application_system_test_case")

class TranslationsSystemTest < ApplicationSystemTestCase
  def test_edit_translation_turbo_form
    # browser = page.driver.browser
    rolf = users("rolf")
    login!(rolf)
    visit(root_path)

    use_test_locales do
      old_one = :one.l
      initial_locale = I18n.locale

      I18n.with_locale(:el) do
        greek_one = :one.l
        # until we figure out why I18n.t("mo.one", default: "") == "Ένα"
        greek_one = greek_one.downcase
        # downcase necessary because of translation glitch
        # if it's fixed, it should be I18n.t("mo.one", default: "") == "ένα"
        # assert_equal(greek_one.downcase, greek_one)

        I18n.with_locale(initial_locale) do
          assert_selector("#translators_credit")
          within("#translators_credit") do
            click_link("translations_index_link")
          end
          assert_selector("body.translations__index")
          within("#translations_index") { first("[data-tag='two']").click }
          assert_selector("#translation_form")

          within("#translation_form") do
            assert_selector("button[type=submit]", text: :SAVE.l, count: 1)
            assert_field("tag_two", type: :textarea, with: "two")
            assert_field("tag_twos", type: :textarea, with: "twos")
            assert_field("tag_TWO", type: :textarea, with: "Two")
            assert_field("tag_TWOS", type: :textarea, with: "Twos")
            click_button("Cancel")
          end
          assert_no_selector("#translation_official")
          assert_no_selector("#translation_form")
          assert_no_selector("#translation_versions")

          # test the reload button
          within("#translations_index") { first("[data-tag='two']").click }
          assert_selector("#translation_form")

          within("#translation_form") do
            fill_in("tag_two", with: "three")
            fill_in("tag_twos", with: "threes")
            fill_in("tag_TWO", with: "Three")
            fill_in("tag_TWOS", with: "Threes")
            click_link("Reload")
            assert_field("tag_two", type: :textarea, with: "two")
            assert_field("tag_twos", type: :textarea, with: "twos")
            assert_field("tag_TWO", type: :textarea, with: "Two")
            assert_field("tag_TWOS", type: :textarea, with: "Twos")
          end

          within("#translations_index") { first("[data-tag='one']").click }
          assert_selector("#translation_form")
          assert_select("locale", selected: "English")
          assert_field("tag_one", type: :textarea, with: old_one)
          fill_in("tag_one", with: "uno")
          within("#translation_form") { click_commit }
          assert_selector("#str_one.translation-updated", text: "uno")

          within("#translations_index") { assert_text("uno") }
          assert_equal("uno", :one.l)
          assert_selector("button[type=submit]", text: :SAVE.l, count: 1)
          assert_field("tag_one", type: :textarea, with: "uno")
          fill_in("tag_one", with: old_one)
          within("#translation_form") { click_commit }
          assert_equal(old_one, :one.l)

          select("Ελληνικά", from: "locale")
          assert_selector("#translation_form h4", text: "Ελληνικά:")
          assert_field("tag_one", type: :textarea, with: greek_one)
          fill_in("tag_one", with: "ichi")
          within("#translation_form") { click_commit }
          within("#translations_index") { assert_text("ichi") }
          assert_equal("one", :one.l)

          assert_selector("button[type=submit]", text: :SAVE.l, count: 1)
          assert_field("tag_one", type: :textarea, with: "ichi")
          I18n.with_locale(:el) { assert_equal("ichi", :one.l) }

          fill_in("tag_one", with: greek_one)
          within("#translation_form") { click_commit }
        end
        assert_equal(greek_one, :one.l)
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

# Full end-to-end check: every real tag/text pair in config/locales/en.txt
# resolves correctly through the ACTUAL I18n.backend configured by
# config/initializers/i18n_backend.rb (I18n::Backend::Chain ->
# SolidCacheKeyValue -> DbFallback -> Simple), not a hand-constructed
# backend instance. The unit tests in db_fallback_test.rb and
# solid_cache_key_value_test.rb pin the individual backends' branch
# logic with a handful of representative tags; this test is the one
# place that proves the real, wired-up Chain resolves every one of
# MO's current production translations, not just a sample.
#
# Deliberately does NOT clean up the cache entries this warms -- they're
# real tags with their real, correct text, so leaving them cached in
# cache_test is harmless (unlike CrossProcessTranslationVisibilityTest's
# synthetic test-only tag, which does need teardown cleanup).
class EnTxtTranslationsTest < UnitTestCase
  # Tags whose DB row is intentionally hand-fixtured with different text
  # than en.txt's current value (see test/fixtures/translation_strings.yml's
  # hand_fixtured_english_tags) -- other tests mutate these rows (e.g.
  # LanguageTest#test_update_localization), so comparing them against
  # en.txt's live text would be comparing against the wrong thing entirely.
  HAND_FIXTURED_TAGS = %w[one two TWO twos TWOS three four all].freeze

  def test_every_en_txt_tag_resolves_through_the_real_chain
    en_txt_path = Rails.root.join("config/locales/en.txt")
    data = YAML.safe_load_file(en_txt_path, permitted_classes: [Symbol])

    tags_checked = 0
    data.each do |tag, expected_text|
      next unless expected_text.is_a?(String)
      next if HAND_FIXTURED_TAGS.include?(tag.to_s)

      actual_text = I18n.t("#{MO.locale_namespace}.#{tag}", locale: :en)
      assert_equal(expected_text, actual_text,
                   "Tag #{tag.inspect} did not resolve correctly")
      tags_checked += 1
    end

    assert_operator(
      tags_checked, :>, 4000,
      "Sanity check: en.txt should have thousands of tags -- a " \
      "suspiciously low count means the YAML parse or the exclusion " \
      "list silently swallowed most of them"
    )
  end
end

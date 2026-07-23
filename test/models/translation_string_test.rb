# frozen_string_literal: true

require("test_helper")

class TranslationStringTest < UnitTestCase
  # Destroying a versioned record must delete its versions, else they're
  # left with a dangling FK (swept by CheckForBrokenReferencesJob).
  def test_destroy_cascades_to_versions
    str = translation_strings(:greek_one)
    version_ids = TranslationString::Version.
                  where(translation_string_id: str.id).pluck(:id)
    assert(version_ids.any?, "fixture should have versions")

    str.destroy!

    assert_empty(TranslationString::Version.where(id: version_ids),
                 "destroying a translation_string should delete its versions")
    # Name and Location share the same cascade config.
    [Name, Location, TranslationString].each do |model|
      assert_equal(
        :delete_all,
        model.reflect_on_association(:versions).options[:dependent],
        "#{model} versions should cascade-delete on destroy"
      )
    end
  end

  def test_rename_tags_upcase
    str = TranslationString.create(
      { tag: "JOHN", text: "Harding",
        user: users(:rolf), language: languages(:english) }
    )
    TranslationString.rename_tags("JOHN" => "FRED")
    assert_nil(TranslationString.find_by(tag: "JOHN"))
    assert_not_nil(TranslationString.find_by(tag: "FRED"))
    assert_equal("Harding", str.reload.text)
    str.update(text: "Wesley")
    assert_equal("Wesley", str.reload.text)

    TranslationString.rename_tags("FRED" => "JOHN")
    assert_nil(TranslationString.find_by(tag: "FRED"))
    assert_not_nil(TranslationString.find_by(tag: "JOHN"))
    assert_equal("Wesley", str.reload.text)
  end

  # #4844's theme-tag migration renamed BlackOnWhite -> black_on_white
  # in production and the non-English rows vanished -- only the English
  # row survived. This reproduces the actual bug shape: one tag with a
  # row in EVERY language, not just English, renamed in a single
  # rename_tags call. If rename_tags (or a caller) ever drops rows for
  # a multi-language tag, this must catch it.
  def test_rename_tags_preserves_every_language_row
    langs = [languages(:english), languages(:french), languages(:greek),
             languages(:russian), languages(:spanish), languages(:portuguese)]
    strs = langs.map do |lang|
      TranslationString.create(
        { tag: "OldMultiLangTag", text: "text in #{lang.locale}",
          user: users(:rolf), language: lang }
      )
    end

    TranslationString.rename_tags("OldMultiLangTag" => "new_multi_lang_tag")

    assert_empty(TranslationString.where(tag: "OldMultiLangTag"))
    renamed = TranslationString.where(tag: "new_multi_lang_tag")
    assert_equal(langs.length, renamed.count,
                 "rename_tags should preserve one row per language, not " \
                 "just English")
    strs.each do |str|
      reloaded = str.reload
      assert_equal("new_multi_lang_tag", reloaded.tag)
      assert_equal("text in #{reloaded.language.locale}", reloaded.text)
    end
  end

  # The actual production bug: rename_tags itself is fine (see above),
  # but Language::Exporter#strip deletes any translation_strings row
  # whose tag isn't in en.txt -- and DB-only tags like black_on_white
  # were, by design, never in en.txt. So any lang:update run (deploy,
  # or manual) after the rename strips every language's row for a
  # DB-only tag, English included. If English still exists afterward
  # in production, it's because a later import:official run recreated
  # it from a since-reverted en.txt line, not because strip spared it.
  def test_strip_deletes_db_only_tag_in_every_language
    langs = [languages(:english), languages(:french), languages(:greek),
             languages(:russian), languages(:spanish), languages(:portuguese)]
    langs.each do |lang|
      TranslationString.create(
        { tag: "db_only_tag_not_in_en_txt", text: "text in #{lang.locale}",
          user: users(:rolf), language: lang }
      )
    end

    langs.each(&:strip)

    assert_empty(
      TranslationString.where(tag: "db_only_tag_not_in_en_txt"),
      "Language::Exporter#strip deletes rows for any tag missing from " \
      "en.txt -- this is exactly what happened to black_on_white's " \
      "non-English translations after the #4844 rename"
    )
  end

  def test_rename_tags_snakecase
    str = TranslationString.create(
      { tag: "interesting_things", text: "Stuff that we may want to know.",
        user: users(:rolf), language: languages(:english) }
    )
    assert_raises(RuntimeError) do
      TranslationString.rename_tags("interesting_things" => "other things")
    end
    assert_not_nil(TranslationString.find_by(tag: "interesting_things"))

    TranslationString.rename_tags("interesting_things" => "other_stuff")
    assert_nil(TranslationString.find_by(tag: "interesting_things"))
    assert_not_nil(TranslationString.find_by(tag: "other_stuff"))
    assert_equal("Stuff that we may want to know.", str.reload.text)
  end

  # The reason for this test is that double spaces in translation strings are
  # "squeezed" to single spaces by Textile, so tests that expect the original
  # string will always fail against rendered results. Simpler not to allow them.
  def test_no_double_spaces_in_en_txt_original_strings
    substring_test("%)  %")
    substring_test("%.  %")
    substring_test("%!  %")
    substring_test("%;  %")
    substring_test("%?  %")
  end

  def substring_test(substring)
    matches = TranslationString.where(language_id: 2).
              where(TranslationString[:text].matches(substring))

    assert_equal(
      0, matches.count,
      "Double space found in translation string :#{matches.first(&:tag)}."
    )
  end

  def test_update_localization_raises_when_locale_not_loaded
    str = translation_strings(:english_one)
    TranslationString.stub(:translations, nil) do
      error = assert_raises(RuntimeError) { str.update_localization }
      assert_includes(error.message, "hasn't been loaded yet")
    end
  end
end

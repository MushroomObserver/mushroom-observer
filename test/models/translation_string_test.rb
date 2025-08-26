# frozen_string_literal: true

require("test_helper")

class TranslationStringTest < UnitTestCase
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

  def test_rename_tags_snakecase
    str = TranslationString.create(
      { tag: "interesting_things", text: "Stuff that we may want to know.",
        user: users(:rolf), language: languages(:english) }
    )
    assert_raises("Tags must be symbols or strings with no spaces.") do
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
end

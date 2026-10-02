# frozen_string_literal: true

require("test_helper")

# A freshly-built backend here shares nothing with the DB/cache-backed
# layers ahead of it in the configured Chain -- proves EnTxtLoader's
# content resolves independent of TranslationString/Solid Cache state,
# which is the point of this fallback layer (#4807).
class I18n::Backend::EnTxtLoaderTest < UnitTestCase
  def test_loads_en_txt_content_under_mo_namespace
    backend = I18n::Backend::EnTxtLoader.call(I18n::Backend::Simple.new)

    assert_equal(
      "must end only in a letter or period",
      backend.send(:lookup, :en, "mo.validate_name_author_ending", [], {})
    )
  end

  def test_returns_the_backend_it_was_given
    simple = I18n::Backend::Simple.new

    assert_same(simple, I18n::Backend::EnTxtLoader.call(simple))
  end
end

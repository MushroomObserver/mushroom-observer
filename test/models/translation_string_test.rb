# frozen_string_literal: true

require("test_helper")

class TranslationStringTest < UnitTestCase
  def test_banner_time
    assert_not_nil(TranslationString.banner_time)
  end
end

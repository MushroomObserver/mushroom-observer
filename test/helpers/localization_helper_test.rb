# frozen_string_literal: true

require("test_helper")

class LocalizationHelperTest < ActionView::TestCase
  def test_rank_as_lower_string
    assert_equal(:rank_genus.l, rank_as_lower_string(:genus),
                 "Expected lowercase localized rank string")
  end

  def test_rank_as_plural_string
    assert_equal(:RANK_PLURAL_GENUS.l, rank_as_plural_string(:genus),
                 "Expected capitalized plural localized rank string")
  end

  def test_rank_as_lower_plural_string
    assert_equal(:rank_plural_genus.l, rank_as_lower_plural_string(:genus),
                 "Expected lowercase plural localized rank string")
  end
end

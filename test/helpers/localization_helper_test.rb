# frozen_string_literal: true

require("test_helper")

class LocalizationHelperTest < ActionView::TestCase
  def test_rank_as_lower_plural_string
    assert_equal(:rank_plural_genus.l, rank_as_lower_plural_string(:genus),
                 "Expected lowercase plural localized rank string")
  end
end

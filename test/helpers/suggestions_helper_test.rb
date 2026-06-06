# frozen_string_literal: true

require("test_helper")

class SuggestionsHelperTest < ActionView::TestCase
  def test_suggestion_confidence_excellent
    val = 90

    assert_equal("#{val.round(2)}% (#{:suggestions_excellent.t})",
                 suggestion_confidence(val),
                 "Expected excellent label for val > 80")
  end

  def test_suggestion_confidence_good
    val = 60

    assert_equal("#{val.round(2)}% (#{:suggestions_good.t})",
                 suggestion_confidence(val),
                 "Expected good label for val > 50")
  end

  def test_suggestion_confidence_fair
    val = 30

    assert_equal("#{val.round(2)}% (#{:suggestions_fair.t})",
                 suggestion_confidence(val),
                 "Expected fair label for val > 25")
  end

  def test_suggestion_confidence_poor
    val = 10

    assert_equal("#{val.round(2)}% (#{:suggestions_poor.t})",
                 suggestion_confidence(val),
                 "Expected poor label for val <= 25")
  end
end

# frozen_string_literal: true

require("test_helper")

class MiniRacerVersionTest < FunctionalTestCase
  def test_mini_racer_evaluates_javascript
    assert_equal(2, MiniRacer::Context.new.eval("1 + 1"))
  end
end

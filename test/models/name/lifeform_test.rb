# frozen_string_literal: true

require("test_helper")

# Tests for Name::Lifeform (app/models/name/lifeform.rb)
class Name::LifeformTest < UnitTestCase
  def test_lichen
    assert(names(:tremella_mesenterica).is_lichen?)
    assert(names(:tremella).is_lichen?)
    assert(names(:tremella_justpublished).is_lichen?)
    assert_not(names(:agaricus_campestris).is_lichen?)
  end
end

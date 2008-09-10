require File.dirname(__FILE__) + '/../test_helper'

class SequenceStateTest < Test::Unit::TestCase
  fixtures :observations

  def test_basic
    state = SequenceState.lookup({:id => 3}, :observations)
    assert_equal(3, state.current_id)
    assert_equal(nil, state.prev_id)
    assert_equal(nil, state.next_id)
    assert_equal(nil, state.current_index)
    assert_equal(2, state.prev)
    assert_equal(3, state.next)
    assert_equal(4, state.next)
  end
end

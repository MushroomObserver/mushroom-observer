require File.dirname(__FILE__) + '/../boot'

class SequenceStateTest < Test::Unit::TestCase
  fixtures :observations
  fixtures :names
  fixtures :users

  def test_basic
    state = SequenceState.lookup({:id => 3}, :observations)
    assert_equal(3, state.current_id)
    assert_equal(4, state.prev)
    assert_equal(3, state.next)
    assert_equal(2, state.next)
    state.save

    search = SearchState.lookup({}, :observations)
    search.setup('title', 'observations.user_id = 1', 'names.search_name asc')
    search.save

    # Observations owned by user 1, sorted by name:
    # agaricus_campestras_obs:     6
    # agaricus_campestris_obs:     4
    # agaricus_campestros_obs:     7
    # agaricus_campestrus_obs:     5
    # coprinus_comatus_obs:        3
    # strobilurus_diminutivus_obs: 8

    sequence = SequenceState.lookup({:search_seq => search.id, :id => 5}, :observations)
    assert_equal(sequence.current_id, 5)
    assert_equal(7, sequence.prev)
    assert_equal(5, sequence.next)
    assert_equal(3, sequence.next)
    assert_equal(8, sequence.next)
    assert_equal(6, sequence.next)
    assert_equal(6, sequence.prev)  # Shouldn't this wrap, as well, if next does?
  end
end

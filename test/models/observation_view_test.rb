# frozen_string_literal: true

require("test_helper")

class ObservationViewTest < UnitTestCase
  def test_basic_stuff
    obs = observations(:minimal_unknown_obs)
    assert_empty(ObservationView.where(observation_id: obs.id,
                                       user_id: dick.id))
    ObservationView.update_view_stats(obs.id, dick.id)
    assert_equal(1,
                 ObservationView.where(observation_id: obs.id,
                                       user_id: dick.id).count)
    assert_operator(obs.last_viewed_by(dick), :>=, 2.seconds.ago)
  end

  def test_update_view_stats_sets_reviewed_true
    obs = observations(:minimal_unknown_obs)
    ObservationView.update_view_stats(obs.id, dick.id, true)

    view = ObservationView.find_by(observation_id: obs.id, user_id: dick.id)
    assert_equal(true, view.reviewed)
  end

  def test_update_view_stats_sets_reviewed_false
    obs = observations(:minimal_unknown_obs)
    # First set to true
    ObservationView.update_view_stats(obs.id, dick.id, true)
    view = ObservationView.find_by(observation_id: obs.id, user_id: dick.id)
    assert_equal(true, view.reviewed)

    # Then set to false - this is the bug fix
    ObservationView.update_view_stats(obs.id, dick.id, false)
    view.reload
    assert_equal(false, view.reviewed,
                 "reviewed should be false after toggling off")
  end

  def test_update_view_stats_leaves_reviewed_unchanged_when_nil
    obs = observations(:minimal_unknown_obs)
    # Set to true
    ObservationView.update_view_stats(obs.id, dick.id, true)
    view = ObservationView.find_by(observation_id: obs.id, user_id: dick.id)
    assert_equal(true, view.reviewed)

    # Update without reviewed parameter - should not change
    ObservationView.update_view_stats(obs.id, dick.id, nil)
    view.reload
    assert_equal(true, view.reviewed,
                 "reviewed should remain unchanged when nil")
  end
end

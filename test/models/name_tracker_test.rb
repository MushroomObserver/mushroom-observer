# frozen_string_literal: true

require("test_helper")

# test the NameTracker model
class NameTrackerTest < UnitTestCase
  def test_summary
    name_tracker = name_trackers(:coprinus_comatus_name_tracker)
    assert_match(name_tracker.name.display_name, name_tracker.summary)

    interest = Interest.find_by(target: name_tracker)
    assert_equal("NameTracker", interest.target_type)
    assert_equal(name_tracker.id, interest.target_id)
  end

  def test_no_user
    name_tracker = name_trackers(:coprinus_comatus_name_tracker)
    name_tracker.user = nil

    assert_not(name_tracker.save)
    assert(name_tracker.errors[:user].any?)
  end
end

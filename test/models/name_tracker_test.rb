# frozen_string_literal: true

require("test_helper")

# test the NameTracker model
class NameTrackerTest < UnitTestCase
  def test_summary
    name_tracker = name_trackers(:coprinus_comatus_notification)
    obj = Name.find(name_tracker.obj_id)
    assert_match(obj.display_name, name_tracker.summary)

    # notification = name_trackers(:bad_flavor_notification)
    # assert_equal("Unrecognized notification flavor", notification.summary)
  end

  def test_no_user
    name_tracker = name_trackers(:coprinus_comatus_notification)
    name_tracker.user = nil

    assert_not(name_tracker.save)
    assert(name_tracker.errors[:user].any?)
  end
end

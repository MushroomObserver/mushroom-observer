# frozen_string_literal: true

require("test_helper")

# test the Notification model
class NotificationTest < UnitTestCase
  def test_summary
    notification = notifications(:coprinus_comatus_notification)
    obj = Name.find(notification.obj_id)
    assert_match(obj.display_name, notification.summary)

    notification = notifications(:bad_flavor_notification)
    assert_equal("Unrecognized notification flavor", notification.summary)
  end
end

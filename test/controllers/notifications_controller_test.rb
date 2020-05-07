require "test_helper"

class NotificationsControllerTest < FunctionalTestCase

  # ------------------------------------------------------------
  #
  # ------------------------------------------------------------


  def test_show_notifications
    # First, create a naming notification email, making sure it has a template,
    # and making sure the person requesting the notifcation is not the same
    # person who created the underlying observation (otherwise nothing happens).
    note = notifications(:coprinus_comatus_notification)
    note.user = mary
    note.note_template = "blah!"
    assert(note.save)
    QueuedEmail.queue_emails(true)
    QueuedEmail::NameTracking.create_email(
      note, namings(:coprinus_comatus_other_naming)
    )

    # Now we can be sure show_notifications is supposed to actually show a
    # non-empty list, and thus that this test is meaningful.
    requires_login(:show,
                   id: observations(:coprinus_comatus_obs).id)
    assert_template(:show)
    QueuedEmail.queue_emails(false)
  end

end

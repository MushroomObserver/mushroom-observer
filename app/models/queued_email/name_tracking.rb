# frozen_string_literal: true

# Name Tracking Email
class QueuedEmail::NameTracking < QueuedEmail
  def notification
    get_object(:notification, Notification)
  end

  def naming
    get_object(:naming, Naming)
  end

  def self.create_email(notification, naming)
    raise("Missing notification!") unless notification
    raise("Missing naming!")       unless naming

    sender = notification.user
    observer = naming.observation.user
    result = nil
    if sender != observer
      result = create(sender, observer)
      result.add_integer(:notification, notification.id)
      result.add_integer(:naming, naming.id)
      result.finish
    end
    result
  end

  def deliver_email
    # Make sure naming wasn't deleted since email was queued.
    if naming
      result = NamingTrackerMailer.build(user, naming).deliver_now
      if notification.note_template
        result = NamingObserverMailer.build(
          to_user, naming, notification
        ).deliver_now
      end
    end
    result
  end
end

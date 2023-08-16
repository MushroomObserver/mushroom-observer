# frozen_string_literal: true

# Name Tracking Email
class QueuedEmail
  class NameTracking < QueuedEmail
    def name_tracker
      get_object(:name_tracker, NameTracker)
    end

    def naming
      get_object(:naming, Naming)
    end

    def self.create_email(name_tracker, naming)
      raise("Missing name_tracker!") unless name_tracker
      raise("Missing naming!")       unless naming

      sender = name_tracker.user
      observer = naming.observation.user
      result = nil
      if sender != observer
        result = create(sender, observer)
        result.add_integer(:name_tracker, name_tracker.id)
        result.add_integer(:naming, naming.id)
        result.finish
      end
      result
    end

    def deliver_email
      # Make sure naming wasn't deleted since email was queued.
      if naming
        result = NamingTrackerMailer.build(user, naming).deliver_now
        if name_tracker.note_template.present? && name_tracker.approved
          result = NamingObserverMailer.build(
            to_user, naming, name_tracker
          ).deliver_now
        end
      end
      result
    end
  end
end

# encoding: utf-8
#
#  = Name Tracking Email
#
#  This email is sent whenever someone proposes a name that another user is
#  tracking.  See QueuedEmail::NameProposal for other emails triggered at the same
#  time.
#
#  == Associated data
#
#  notification::   integer, refers to a Notification id
#  naming::         integer, refers to a Naming id
#
#  == Class methods
#
#  create_email::   Create new email.
#
#  == Instance methods
#
#  notification::   Get instance of Notification that tracks this name.
#  naming::         Get instance of Naming that triggered this email.
#  deliver_email::  Deliver via AccountMailer#deliver_naming_for_tracker.
#
################################################################################

class QueuedEmail::NameTracking < QueuedEmail
  def notification; get_object(:notification, Notification); end
  def naming;       get_object(:naming, Naming);             end

  def self.create_email(notification, naming)
    raise "Missing notification!" if !notification
    raise "Missing naming!"       if !naming
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
      result = AccountMailer.naming_for_tracker(user, naming).deliver
      if notification.note_template
        result = AccountMailer.naming_for_observer(to_user, naming, notification).deliver
      end
    end
    return result
  end
end

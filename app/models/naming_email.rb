# Class for holding code specific to QueuedEmails intended to send email_naming emails.
#
# The separation is nice, but it kind of violates some of Rails assumptions.  In particular,
# the initialize if dangerous since it does saves.  However, I can't figure out a way to
# get these out of the database so as long the creation is explicit in code things should
# be fine.
class NamingEmail < QueuedEmail
  def self.create_email(notification, naming)
    sender = notification.user
    observer = naming.observation.user
    result = nil
    if sender != observer
      result = QueuedEmail.new()
      result.setup(sender, observer, :naming)
      result.save()
      result.add_integer(:naming, naming.id)
      result.add_integer(:notification, notification.id)
      result.finish()
    end
    result
  end
  
  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def self.deliver_email(email)
    naming = nil
    notification = nil
    (naming_id, notification_id) = email.get_integers([:naming, :notification])
    naming = Naming.find(naming_id) if naming_id
    notification = Notification.find(notification_id) if notification_id
    if naming
      if email.user != email.to_user
        AccountMailer.deliver_naming_for_tracker(email.user, naming)
        if notification && notification.note_template
          AccountMailer.deliver_naming_for_observer(email.to_user, naming, notification)
        end
      else
        print "Skipping email with same sender and recipient, #{email.user.email}\n"
      end
    else
      print "No naming found (#{email.id})\n"
    end
  end
end

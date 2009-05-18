# Class for holding code specific to QueuedEmails intended to send email_features emails.
#
# The separation is nice, but it kind of violates some of Rails assumptions.
# The initialize is dangerous since it does saves.  However, I can't figure out
# a way to get these out of the database.  As long as the creation is explicit
# in code things should be fine. 
class FeatureEmail < QueuedEmail
  def self.create_email(receiver, note)
    result = FeatureEmail.new()
    result.setup(nil, receiver, :feature)
    result.save()
    result.set_note(note)
    result.finish()
    result
  end
  
  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def deliver_email
    note = queued_email_note.value
    if note
      if to_user.feature_email # Make sure it hasn't changed
        AccountMailer.deliver_email_features(to_user, note)
      end
    else
      print "No note found (#{self.id})\n"
    end
  end
end

# Class for holding code specific to QueuedEmails intended to send email_features emails.
#
# The separation is nice, but it kind of violates some of Rails assumptions.  In particular,
# the initialize if dangerous since it does saves.  However, I can't figure out a way to
# get these out of the database so as long the creation is explicit in code things should
# be fine.
class FeatureEmail < QueuedEmail
  def self.create_email(receiver, note)
    result = QueuedEmail.new()
    result.setup(nil, receiver, :feature)
    result.save()
    result.set_note(note)
    result.finish()
    result
  end
  
  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def self.deliver_email(email)
    note = email.queued_email_note.value
    if note
      if email.to_user.feature_email # Make sure it hasn't changed
        AccountMailer.deliver_email_features(email.to_user, note)
      end
    else
      print "No note found (#{email.id})\n"
    end
  end
end

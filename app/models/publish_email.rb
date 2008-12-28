# Class for holding code specific to QueuedEmails intended to send email_features emails.
#
# The separation is nice, but it kind of violates some of Rails assumptions.
# The initialize is dangerous since it does saves.  However, I can't figure out
# a way to get these out of the database.  As long as the creation is explicit
# in code things should be fine. 
class PublishEmail < QueuedEmail
  def self.create_email(publisher, receiver, name)
    result = QueuedEmail.new()
    result.setup(publisher, receiver, :publish)
    result.save()
    result.add_integer(:name, name.id)
    result.finish()
    result
  end
  
  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def self.deliver_email(email)
    name = nil
    name_id = email.get_integers([:name])[0]
    name = Name.find(name_id) if name_id
    if name
      if email.user != email.to_user
        AccountMailer.deliver_publish_name(email.user, email.to_user, name)
      else
        print "Skipping email with same sender and recipient, #{email.user.email}\n"
      end
    else
      print "No name found (#{email.id})\n"
    end
  end
end

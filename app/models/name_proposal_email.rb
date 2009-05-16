# Class for holding code specific to QueuedEmails intended to send email_naming emails.
#
# The separation is nice, but it kind of violates some of Rails assumptions.  In particular,
# the initialize if dangerous since it does saves.  However, I can't figure out a way to
# get these out of the database so as long the creation is explicit in code things should
# be fine.
class NameProposalEmail < QueuedEmail
  def self.create_email(sender, recipient, observation, naming)
    result = NameProposalEmail.new()
    result.setup(sender, recipient, :name_proposal)
    result.save()
    result.add_integer(:naming, naming.id)
    result.add_integer(:observation, observation.id)
    result.finish()
    result
  end
  
  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def self.deliver_email(email)
    naming = nil
    observation = nil
    (naming_id, observation_id) = email.get_integers([:naming, :observation])
    naming = Naming.find(naming_id) if naming_id
    observation = Observation.find(observation_id) if observation_id
    if !naming
      print "No naming found for email ##{email.id}.\n"
    elsif !observation
      print "No observation found for email ##{email.id}.\n"
    elsif email.user == email.to_user
      print "Skipping email with same sender and recipient: #{email.user.email}\n"
    else
      AccountMailer.deliver_name_proposal(email.user, email.to_user, naming, observation)
    end
  end
end

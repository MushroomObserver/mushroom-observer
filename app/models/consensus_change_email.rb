# Class for holding code specific to QueuedEmails intended to send email_naming emails.
#
# The separation is nice, but it kind of violates some of Rails assumptions.  In particular,
# the initialize if dangerous since it does saves.  However, I can't figure out a way to
# get these out of the database so as long the creation is explicit in code things should
# be fine.
class ConsensusChangeEmail < QueuedEmail
  def self.create_email(sender, recipient, observation, old_name, new_name)
    result = QueuedEmail.new()
    result.setup(sender, recipient, :consensus_change)
    result.save()
    result.add_integer(:observation, observation.id)
    result.add_integer(:old_name, old_name.id)
    result.add_integer(:new_name, new_name.id)
    result.finish()
    result
  end
  
  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def self.deliver_email(email)
    observation = nil
    old_name = nil
    new_name = nil
    (observation_id, old_name_id, new_name_id) =
      email.get_integers([:observation, :old_name, :new_name])
    observation = Observation.find(observation_id) if observation_id
    old_name = Name.find(old_name_id) if old_name_id
    new_name = Name.find(new_name_id) if new_name_id
    if !observation
      print "No observation found for email ##{email.id}.\n"
    elsif email.user == email.to_user
      print "Skipping email with same sender and recipient: #{email.user.email}\n"
    else
      AccountMailer.deliver_consensus_change(email.user, email.to_user, observation, old_name, new_name)
    end
  end
end

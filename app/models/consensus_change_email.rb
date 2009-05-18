# Class for holding code specific to QueuedEmails intended to send email_naming emails.
#
# The separation is nice, but it kind of violates some of Rails assumptions.  In particular,
# the initialize if dangerous since it does saves.  However, I can't figure out a way to
# get these out of the database so as long the creation is explicit in code things should
# be fine.
class ConsensusChangeEmail < QueuedEmail
  def self.create_email(sender, recipient, observation, old_name, new_name)
    result = ConsensusChangeEmail.new()
    result.setup(sender, recipient, :consensus_change)
    result.save()
    result.observation = observation
    result.old_name = old_name
    result.new_name = new_name
    result.finish()
    result
  end
  
  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def deliver_email
    if !observation
      print "No observation found for email ##{self.id}.\n"
    elsif user == to_user
      print "Skipping email with same sender and recipient: #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_consensus_change(user, to_user, observation, old_name, new_name, queued)
    end
  end

  # ----------------------------
  #  Accessors
  # ----------------------------

  def observation=(observation)
    @observation = observation
    self.add_integer(:observation, observation.id)
  end

  def old_name=(name)
    @old_name = name
    self.add_integer(:old_name, name.id)
  end

  def new_name=(name)
    @new_name = name
    self.add_integer(:new_name, name.id)
  end

  def observation
    begin
      @observation ||= Observation.find(self.get_integer(:observation))
    rescue
    end
    @observation
  end

  def old_name
    begin
      @old_name ||= Name.find(self.get_integer(:old_name))
    rescue
    end
    @old_name
  end

  def new_name
    begin
      @new_name ||= Name.find(self.get_integer(:new_name))
    rescue
    end
    @new_name
  end
end

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
    result.naming = naming
    result.observation = observation
    result.finish()
    result
  end
  
  # While this looks like it could be an instance method, it has to be a class
  # method for QueuedEmails that come out of the database to work.  See queued_emails.rb
  # for more details.
  def deliver_email
    if !naming
      print "No naming found for email ##{self.id}.\n"
    elsif !observation
      print "No observation found for email ##{self.id}.\n"
    elsif user == to_user
      print "Skipping email with same sender and recipient: #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_name_proposal(user, to_user, naming, observation)
    end
  end

  # ----------------------------
  #  Accessors
  # ----------------------------

  def naming=(naming)
    @naming = naming
    self.add_integer(:naming, naming.id);
  end

  def observation=(observation)
    @observation = observation
    self.add_integer(:observation, observation.id);
  end

  def naming
    begin
      @naming ||= Naming.find(self.get_integer(:naming))
    rescue
    end
    @naming
  end

  def observation
    begin
      @observation ||= Observation.find(self.get_integer(:observation))
    rescue
    end
    @observation
  end
end

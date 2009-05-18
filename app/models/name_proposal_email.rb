class NameProposalEmail < BaseEmail
  attr_accessor :naming
  attr_accessor :observation

  def initialize(email)
    self.naming      = Naming.find(email.get_integer(:naming))
    self.observation = Observation.find(email.get_integer(:observation))
    super(email)
  end

  def self.create_email(sender, recipient, observation, naming)
    result = QueuedEmail.new()
    result.setup(sender, recipient, :name_proposal)
    result.save()
    result.add_integer(:naming, naming.id)
    result.add_integer(:observation, observation.id)
    result.finish()
    result
  end
  
  def deliver_email
    if !naming
      raise "No naming found for email ##{self.id}"
    elsif !observation
      raise "No observation found for email ##{self.id}"
    elsif user == to_user
      print "Skipping email with same sender and recipient: #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_name_proposal(user, to_user, naming, observation)
    end
  end
end

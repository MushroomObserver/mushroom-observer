class ConsensusChangeEmail < QueuedEmailSubclass
  attr_accessor :observation
  attr_accessor :old_name
  attr_accessor :new_name

  def initialize(email)
    observation_id = email.get_integer(:observation)
    old_name_id    = email.get_integer(:old_name)
    new_name_id    = email.get_integer(:new_name)
    self.observation = Observation.find(observation_id)
    self.old_name    = old_name_id > 0 ? Name.find(old_name_id) : nil
    self.new_name    = new_name_id > 0 ? Name.find(new_name_id) : nil
    super(email)
  end

  def self.create_email(sender, recipient, observation, old_name, new_name)
    result = QueuedEmail.new()
    result.setup(sender, recipient, :consensus_change)
    result.save()
    result.add_integer(:observation, observation.id)
    result.add_integer(:old_name, old_name ? old_name.id : 0)
    result.add_integer(:new_name, new_name ? new_name.id : 0)
    result.finish()
    result
  end
  
  def deliver_email
    if !observation
      raise "No observation found for email ##{self.id}"
    elsif user == to_user
      print "Skipping email with same sender and recipient: #{user.email}\n" if !TESTING
    else
      AccountMailer.deliver_consensus_change(user, to_user, observation, old_name, new_name, queued)
    end
  end
end

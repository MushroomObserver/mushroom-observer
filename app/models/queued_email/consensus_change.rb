# Consensus Change Email
class QueuedEmail::ConsensusChange < QueuedEmail
  def observation
    get_object(:observation, ::Observation)
  end

  def old_name
    get_object(:old_name, ::Name, :allow_nil)
  end

  def new_name
    get_object(:new_name, ::Name, :allow_nil)
  end

  def self.create_email(sender, recipient, observation, old_name, new_name)
    result = create(sender, recipient)
    fail "Missing observation!" unless observation

    result.add_integer(:observation, observation.id)
    result.add_integer(:old_name, old_name ? old_name.id : 0)
    result.add_integer(:new_name, new_name ? new_name.id : 0)
    result.finish
    result
  end

  def deliver_email
    # Make sure it hasn't been deleted since email was queued.
    return unless observation && old_name && new_name

    ConsensusChangeEmail.build(self).deliver_now
  end
end

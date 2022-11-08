# frozen_string_literal: true

# Name Proposal Email
class QueuedEmail::NameProposal < QueuedEmail
  def naming
    get_object(:naming, Naming)
  end

  def observation
    get_object(:observation, Observation)
  end

  def self.create_email(sender, recipient, observation, naming)
    result = create(sender, recipient)
    raise("Missing naming!")      unless naming
    raise("Missing observation!") unless observation

    result.add_integer(:naming, naming.id)
    result.add_integer(:observation, observation.id)
    result.finish
    result
  end

  def deliver_email
    # Make sure nothing's been deleted since email was queued.
    return unless naming && observation

    NameProposalMailer.build(user, to_user, naming, observation).deliver_now
  end
end

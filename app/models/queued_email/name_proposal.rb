# encoding: utf-8

# Name Proposal Email
class QueuedEmail::NameProposal < QueuedEmail
  def naming;      get_object(:naming, Naming);           end
  def observation; get_object(:observation, Observation); end

  def self.create_email(sender, recipient, observation, naming)
    result = create(sender, recipient)
    raise "Missing naming!"      if !naming
    raise "Missing observation!" if !observation
    result.add_integer(:naming, naming.id)
    result.add_integer(:observation, observation.id)
    result.finish
    return result
  end
  
  def deliver_email
    # Make sure nothing's been deleted since email was queued.
    if naming && observation
      NameProposalEmail.build(user, to_user, naming, observation).deliver
    end
  end
end

#
#  = Name Proposal Email
#
#  This email is sent whenever someone proposes a new name for an Observation.
#  It is sent to:
#
#  1. the owner of the Observation
#  2. anyone "interested in" the Observation
#
#  *NOTE*: Users who are tracking a name will get a different type of email,
#  QueuedEmail::Naming.
#
#  == Associated data
#
#  naming::         integer, refers to a Naming id
#  observation::    integer, refers to a Observation id
#
#  == Class methods
#
#  create_email::  Create new email.
#
#  == Instance methods
#
#  naming::         Get instance of Observation in question.
#  observation::    Get instance of new Naming.
#  deliver_email::  Deliver via AccountMailer#deliver_name_proposal.
#
################################################################################

class QueuedEmail::NameProposal < QueuedEmail
  def naming;      get_object(:naming, ::Naming);           end
  def observation; get_object(:observation, ::Observation); end

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
    AccountMailer.deliver_name_proposal(user, to_user, naming, observation)
  end
end

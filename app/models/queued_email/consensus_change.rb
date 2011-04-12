# encoding: utf-8
#
#  = Consensus Change Email
#
#  This email is sent whenever the consensus name changes for an observation.
#  It is sent to:
#
#  1. the owner of the observation
#  2. anyone "interested in" the observation
#
#  == Associated data
#
#  observation:: integer, refers to an Observation id
#  old_name::    integer, refers to a Name id
#  new_name::    integer, refers to a Name id
#
#  == Class methods
#
#  create_email:: Creates new email.
#
#  *NOTE*: It creates a new email every time the name changes so that the owner
#  receives the full history of changes.
#
#  == Instance methods
#
#  observation::    Get instance of Observation.
#  old_name::       Get instance of previous consensus Name.
#  new_name::       Get instance of current consensus Name.
#  deliver_email::  Deliver via AccountMailer#deliver_conensus_change.
#
################################################################################

class QueuedEmail::ConsensusChange < QueuedEmail
  def observation; get_object(:observation, ::Observation);   end
  def old_name;    get_object(:old_name, ::Name, :allow_nil); end
  def new_name;    get_object(:new_name, ::Name, :allow_nil); end

  def self.create_email(sender, recipient, observation, old_name, new_name)
    result = create(sender, recipient)
    raise "Missing observation!" if !observation
    result.add_integer(:observation, observation.id)
    result.add_integer(:old_name, old_name ? old_name.id : 0)
    result.add_integer(:new_name, new_name ? new_name.id : 0)
    result.finish
    return result
  end

  def deliver_email
    # Make sure it hasn't been deleted since email was queued.
    if observation && old_name && new_name
      AccountMailer.deliver_consensus_change(user, to_user, observation,
                                             old_name, new_name, queued)
    end
  end
end

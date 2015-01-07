# encoding: utf-8
#
#  = Specimens Model
#
#  Specimens of Observations
#
#  == Attributes
#
#  id::               Locally unique numerical id, starting at 1.
#  herbarium_id::     id of MO Herbarium containing the Specimen
#  when::             date specimen was created
#  notes::            user notes about Specimen
#  user_id::          id of user who created Specimen
#  herbarium_label::  text label for Specimen
#  created_at::       Date/time it was last updated.
#  updated_at::       Date/time it was last updated.
#
#  == Class methods
#
#  None
#
#  == Instance methods
#
#  can_edit(user)
#  add_observation(obs)
#  clear_observations
#  notify curators        email curators of Herbarium when non-curator adds
#                         Specimen to a Herbarium
#
#  == Callbacks
#
#  None.
#
################################################################################

class Specimen < AbstractModel
  belongs_to :herbarium
  belongs_to :user
  has_and_belongs_to_many :observations

  # Used to allow location name to be entered as text in forms
  attr_accessor :herbarium_name

  after_create :notify_curators

  def can_edit?(user)
    user && ((self.user == user) || herbarium.is_curator?(user))
  end

  def add_observation(obs)
    self.observations.push(obs)
    obs.specimen = true # Hmm, this feels a little odd
    obs.log(:log_specimen_added, name: herbarium_label, touch: true)
    obs.save
  end

  def clear_observations
    observations.clear
    self.save
  end

  # Send email notifications when specimen created by non-curator.
  def notify_curators
    sender = User.current
    recipients = herbarium.curators # Should people with interest in related
                                    # observations get notified?
    return if recipients.member?(sender) # Only worry about non-curators

    for recipient in recipients
      if recipient.created_here
        QueuedEmail::AddSpecimenNotCurator.create_email(sender, recipient, self)
      end
    end
  end
end

class Specimen < AbstractModel
  belongs_to :herbarium
  belongs_to :user
  has_and_belongs_to_many :observations
  
  # Used to allow location name to be entered as text in forms
  attr_accessor :herbarium_name
  
  after_create :notify_curators

  def can_edit?(user)
    user and ((self.user == user) or herbarium.is_curator?(user))
  end

  def add_observation(obs)
    self.observations.push(obs)
    obs.specimen = true # Hmm, this feels a little odd
    obs.log(:log_specimen_added, :name => herbarium_label, :touch => true)
    obs.save
  end

  # Send email notifications when specimen created by non-curator.
  def notify_curators
    sender = User.current
    recipients = herbarium.curators # Should people with interest in related observations get notified?
    if !recipients.member?(sender) # Only worry about non-curators
      for recipient in recipients
        if recipient.created_here
          QueuedEmail::AddSpecimenNotCurator.create_email(sender, recipient, self)
        end
      end
    end
  end
end

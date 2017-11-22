#
#  = HerbariumRecords Model
#
#  Represents a record of a physical collection at an herbarium.  Each time
#  a specimen is accessioned at an herbarium it will be given a label and a
#  unique identifier.  This info can be stored in this record.
#
#  Each HerbariumRecord belongs to an Herbarium, and can belong to one or
#  more Observation(s).  Note that either an observer or an Herbarium curator
#  can create one of these records.
#
#  See also CollectionNumber.
#
#  == Attributes
#
#  id::               Locally unique numerical id, starting at 1.
#  user_id::          Id of User who created this record at MO.
#  created_at::       Date/time this record was created at MO.
#  updated_at::       Date/time this record was last updated at MO.
#  herbarium_id::     Id of Herbarium containing this record.
#  herbarium_label::  Label for the specimen, typically the initial
#                     determination and the  collector's name and number.
#  notes::            Random notes about this record (optional).
#
#  == Class methods
#
#  None
#
#  == Instance methods
#
#  observations::         Observations associated with this record.
#  can_edit(user)::       Can a given user edit this record?
#  add_observation(obs):: Add record to Observation, log it and save.
#
#  == Callbacks
#
#  notify curators::  Email curators when non-curator adds a record to an
#                     Herbarium.  Called after create.
#
class HerbariumRecord < AbstractModel
  belongs_to :herbarium
  belongs_to :user
  has_and_belongs_to_many :observations

  # Used to allow herbarium name to be entered as text in forms.
  attr_accessor :herbarium_name

  after_create :notify_curators

  # Can a given user edit this HerbariumRecord?
  def can_edit?(user)
    self.user == user || herbarium.is_curator?(user)
  end

  # Add this HerbariumRecord to an Observation, log the action, and save it.
  def add_observation(obs)
    observations.push(obs)
    obs.specimen = true
    obs.log(:log_herbarium_record_added, name: herbarium_label, touch: true)
    obs.save
  end

  # Send email notifications when herbarium_record created by non-curator.
  def notify_curators
    sender = User.current
    recipients = herbarium.curators
    return if recipients.member?(sender)
    recipients.each do |recipient|
      email_klass = QueuedEmail::AddHerbariumRecordNotCurator
      email_klass.create_email(sender, recipient, self)
    end
  end
end

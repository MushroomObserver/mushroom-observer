# frozen_string_literal: true

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
#  initial_det::      Initial determination of the specimen.
#  accession_number:: Herbarium's unique identifier number.
#  notes::            Random notes about this record (optional).
#
#  == Class methods
#
#  None
#
#  == Instance methods
#
#  observations::     Observations associated with this record.
#  can_edit?::        Can a given user edit this record?
#  add_observation::  Add record to Observation, log it and save.
#  herbarium_label::  Initial determination + accession number.
#  format_name::      Same as herbarium_label.
#  accession_at_herbarium:: Format as "spec #nnnn @ Herbarium".
#  mcp_url::          URL for corresponding MycoPortal record
#
#  == Callbacks
#
#  notify curators::  Email curators when non-curator adds a record to an
#                     Herbarium.  Called after create.
#
class HerbariumRecord < AbstractModel
  belongs_to :herbarium
  belongs_to :user

  has_many :observation_herbarium_records, dependent: :destroy
  has_many :observations, through: :observation_herbarium_records

  # Used to allow herbarium name to be entered as text in forms.
  attr_accessor :herbarium_name

  after_create :notify_curators
  before_update :log_update
  before_destroy :log_destroy

  scope :order_by_default,
        -> { order_by(::Query::HerbariumRecords.default_order) }

  scope :observations, lambda { |obs|
    joins(:observation_herbarium_records).
      where(observation_herbarium_records: { observation: obs })
  }
  scope :herbaria,
        ->(herbaria) { where(herbarium: herbaria) }

  scope :has_notes,
        ->(bool = true) { not_blank_condition(HerbariumRecord[:notes], bool:) }
  scope :notes_has,
        ->(str) { search_columns(HerbariumRecord[:notes], str) }

  scope :initial_det, lambda { |val|
    exact_match_condition(HerbariumRecord[:initial_det], val)
  }
  scope :initial_det_has,
        ->(str) { search_columns(HerbariumRecord[:initial_det], str) }

  scope :accession, lambda { |val|
    exact_match_condition(HerbariumRecord[:accession_number], val)
  }
  scope :accession_has,
        ->(str) { search_columns(HerbariumRecord[:accession_number], str) }

  scope :pattern, lambda { |phrase|
    cols = (HerbariumRecord[:initial_det] +
            HerbariumRecord[:accession_number] +
            HerbariumRecord[:notes].coalesce(""))
    search_columns(cols, phrase).distinct
  }

  def herbarium_label
    if initial_det.blank?
      accession_number
    else
      "#{initial_det}: #{accession_number}"
    end
  end

  def format_name
    herbarium_label
  end

  def accession_at_herbarium
    "__#{accession_number}__ @ #{herbarium.try(&:format_name)}"
  end

  def mcp_url
    herbarium.mcp_url(accession_number)
  end

  # Can a given user edit this HerbariumRecord?
  def can_edit?(user)
    return false unless user

    self.user == user || herbarium&.curator?(user)
  end

  # Send email notifications when herbarium_record created by non-curator.
  # Migrated from QueuedEmail::AddRecordToHerbarium to ActionMailer + ActiveJob.
  def notify_curators
    sender = user
    recipients = herbarium.try(&:curators) || []
    return if recipients.member?(sender)

    recipients.each do |receiver|
      next if receiver.no_emails

      AddHerbariumRecordMailer.build(
        sender:, receiver:, herbarium_record: self
      ).deliver_later
    end
  end

  # Add this HerbariumRecord to an Observation, make sure the observation
  # reports a specimen available, and log the action.
  def add_observation(obs)
    return if observations.include?(obs)

    observations.push(obs)
    obs.update(specimen: true) unless obs.specimen
    obs.user_log(user, :log_herbarium_record_added,
                 name: accession_at_herbarium,
                 touch: true)
  end

  # Remove this HerbariumRecord from an Observation and log the action.
  def remove_observation(obs)
    return unless observations.include?(obs)

    observations.delete(obs)
    obs.reload.turn_off_specimen_if_no_more_records
    obs.log(:log_herbarium_record_removed,
            name: accession_at_herbarium,
            touch: true)
    destroy if observations.empty?
  end

  def log_update
    observations.each do |obs|
      if herbarium_id_was == herbarium_id
        obs.log(:log_herbarium_record_updated,
                name: accession_at_herbarium,
                touch: true)
      else
        obs.log(:log_herbarium_record_moved,
                to: accession_at_herbarium,
                touch: true)
      end
    end
  end

  def log_destroy
    observations.each do |obs|
      obs.log(:log_herbarium_record_removed,
              name: accession_at_herbarium,
              touch: true)
    end
  end
end

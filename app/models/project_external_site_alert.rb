# frozen_string_literal: true

#
#  = Project External Site Alert
#
#  What MO has told a project's admins about, one row per project per
#  identification on the external site (#5416).
#
#  The row is the record that an identification has been alerted on, so
#  the same one does not alert twice. It also holds what the message
#  said: the name applied, the watched name it matched, the date the
#  mushroom was seen, and which of the two messages it went in (#5677)
#  -- a find, or activity on an observation already reported.
#
#  == Class methods
#
#  record::  create the row for an identification, or nil when it has
#            already been alerted on
#
#  == Instance methods
#
#  remote_url::        the observation's page on the site it came from
#  new_observation?::  is this a find rather than later activity
#  message_key::       which message this alert belongs in
#
class ProjectExternalSiteAlert < AbstractModel
  NEW_OBSERVATION = "new_observation"
  OTHER_ACTIVITY = "other_activity"
  KINDS = [NEW_OBSERVATION, OTHER_ACTIVITY].freeze

  belongs_to :project
  belongs_to :external_site

  validates :remote_identification_id, presence: true
  validates :remote_observation_id, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :target_name, presence: true

  scope :for_project, ->(project) { where(project: project) }
  scope :order_by_default, -> { order(alerted_at: :desc, id: :desc) }

  # Nil when this project has already been told about this
  # identification. The unique index is what decides that, so two
  # cycles running at once cannot both send.
  def self.record(project:, external_site:, identification:, observation:,
                  target_name:)
    observation_id = observation[:id].to_s
    create!(project: project, external_site: external_site,
            remote_identification_id: identification[:id].to_s,
            remote_observation_id: observation_id,
            name: identification[:name], target_name: target_name,
            kind: kind_for(project, external_site, observation_id),
            observed_on: observation[:observed_on],
            alerted_at: Time.zone.now)
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  # A find the first time, activity after that: a project told about an
  # observation hears about a confirming or disagreeing identification
  # on it as activity, not as something new.
  def self.kind_for(project, external_site, observation_id)
    told = exists?(project: project, external_site: external_site,
                   remote_observation_id: observation_id)
    told ? OTHER_ACTIVITY : NEW_OBSERVATION
  end

  # The observation's page on the site it came from.
  def remote_url
    external_site&.observation_url(remote_observation_id)
  end

  def new_observation?
    kind == NEW_OBSERVATION
  end

  # What groups alerts into messages: one message per watched name per
  # kind, so a subject line can name the taxon.
  def message_key
    [kind, target_name.to_s]
  end
end

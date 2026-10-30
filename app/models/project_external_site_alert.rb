# frozen_string_literal: true

#
#  = Project External Site Alert
#
#  What MO has told a project's admins about, one row per project per
#  identification on the external site (#5416).
#
#  The row is the record that an identification has been alerted on, so
#  a later edit to the same observation -- a comment, a photo, another
#  identification -- does not alert again. It also holds what the
#  message said: the name applied and the date the mushroom was seen.
#
#  == Class methods
#
#  record::  create the row for an identification, or nil when it has
#            already been alerted on
#
class ProjectExternalSiteAlert < AbstractModel
  belongs_to :project
  belongs_to :external_site

  validates :remote_identification_id, presence: true
  validates :remote_observation_id, presence: true

  scope :for_project, ->(project) { where(project: project) }
  scope :order_by_default, -> { order(alerted_at: :desc, id: :desc) }

  # Nil when this project has already been told about this
  # identification. The unique index is what decides that, so two
  # cycles running at once cannot both send.
  def self.record(project:, external_site:, identification:, observation:)
    create!(project: project, external_site: external_site,
            remote_identification_id: identification[:id].to_s,
            remote_observation_id: observation[:id].to_s,
            name: identification[:name], observed_on: observation[:observed_on],
            alerted_at: Time.zone.now)
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  # The observation's page on the site it came from.
  def remote_url
    external_site&.observation_url(remote_observation_id)
  end
end

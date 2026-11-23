# frozen_string_literal: true

# One message per subscriber per watched name per kind, naming the
# observations newly identified as something the project watches
# (#5416). The source may be an external site or MO (#5721).
#
# A digest rather than a message per identification: a taxon swap on
# iNat landing on a watched name would be surprising, but it is the
# case that would otherwise flood an inbox. The subject names the
# watched name and says whether this is a find or later activity on
# something already reported (#5677) -- what a coordinator needs to
# decide how soon to follow it up. The count and the projects stay in
# the body, since neither changes what they do about it.
class ProjectAlertMailer < ApplicationMailer
  after_action :news_delivery, only: [:build]

  def build(receiver:, alerts:)
    setup_user(receiver)
    subject = subject_for(alerts)
    debug_log(:project_alert, nil, receiver, count: alerts.size.to_s)
    mo_mail(subject, to: receiver,
                     view_params: { subject: subject, receiver: receiver,
                                    alerts: alerts })
  end

  SUBJECT_TAGS = {
    ProjectAlert::NEW_OBSERVATION =>
      { one: :email_subject_project_alert_find_one,
        many: :email_subject_project_alert_find },
    ProjectAlert::OTHER_ACTIVITY =>
      { one: :email_subject_project_alert_activity_one,
        many: :email_subject_project_alert_activity }
  }.freeze

  private

  def subject_for(alerts)
    alert = alerts.first
    subject_tag(alerts).l(name: alert.target_name.to_s,
                          site: alert.source_name)
  end

  # One observation can match several of the receiver's projects, so
  # the plural follows the observations, not the rows.
  def subject_tag(alerts)
    plurality = alerts.map(&:observation_key).uniq.one? ? :one : :many
    SUBJECT_TAGS.dig(alerts.first.kind, plurality)
  end
end

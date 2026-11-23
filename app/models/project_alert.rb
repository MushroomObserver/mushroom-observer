# frozen_string_literal: true

#
#  = Project Alert
#
#  What MO has told a project's subscribers about: one row per project
#  per thing it was told (#5416, #5721).
#
#  A row from an external site names the identification there, so the
#  same one does not alert twice. A row from MO names the record whose
#  arrival said so -- the Observation, the Naming or the Comment --
#  which plays the same part.
#
#  It also holds what the message said: the name applied, the watched
#  name it matched, the date the mushroom was seen, and which of the
#  two messages it went in (#5677) -- a find, or activity on an
#  observation already reported.
#
#  == Class methods
#
#  record::        the row for an identification on an external site,
#                  or nil when it has already been alerted on
#  record_local::  the same for something that happened here
#  suppress::      run a block whose changes raise no alerts, which is
#                  what an import and a resync do: iNaturalist alerted
#                  on them already
#
#  == Instance methods
#
#  url::               where to read the observation
#  source_name::       the site it came from, or this one
#  observation_key::   what groups rows about one observation
#  new_observation?::  is this a find rather than later activity
#  message_key::       which message this alert belongs in
#
class ProjectAlert < AbstractModel
  NEW_OBSERVATION = "new_observation"
  OTHER_ACTIVITY = "other_activity"
  KINDS = [NEW_OBSERVATION, OTHER_ACTIVITY].freeze

  belongs_to :project
  belongs_to :external_site, optional: true
  belongs_to :observation, optional: true
  belongs_to :target, polymorphic: true, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :target_name, presence: true
  validate :names_what_it_alerted_on

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

  # The same for an observation here, where the target is the record
  # whose arrival said so. Nil when this project has been told about
  # that record already.
  def self.record_local(project:, observation:, target:, name:,
                        target_name:)
    create!(project: project, observation: observation, target: target,
            name: name, target_name: target_name,
            kind: local_kind_for(project, observation, target),
            observed_on: observation.when,
            alerted_at: Time.zone.now)
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  # One message per subscriber per watched name per kind, the way the
  # iNaturalist cycle splits them (#5677), so a subject line can name
  # the taxon.
  def self.deliver_digests(alerts)
    by_recipient(alerts).each do |receiver, received|
      received.group_by(&:message_key).each_value do |message_alerts|
        deliver(receiver, message_alerts)
      end
    end
  end

  def self.by_recipient(alerts)
    digests = Hash.new { |hash, user| hash[user] = [] }
    alerts.compact.each do |alert|
      alert.project.alert_recipients.each do |user|
        digests[user] << alert unless user.no_emails
      end
    end
    digests
  end

  # Isolated per receiver so one failure cannot abort the rest, the
  # same shape the iNaturalist cycle delivers in.
  def self.deliver(receiver, alerts)
    ProjectAlertMailer.build(receiver: receiver, alerts: alerts).
      deliver_later
  rescue StandardError => e
    Rails.logger.error("ProjectAlertMailer enqueue failed for user " \
                       "#{receiver.id}: #{e.class}: #{e.message}")
  end

  # Changes a block makes raise no alerts. An import and a resync use
  # it: what they bring in happened on the other site, which alerted
  # on it already.
  def self.suppress
    previous = Thread.current[:project_alerts_suppressed]
    Thread.current[:project_alerts_suppressed] = true
    yield
  ensure
    Thread.current[:project_alerts_suppressed] = previous
  end

  def self.suppressed?
    Thread.current[:project_alerts_suppressed] || false
  end

  # A find the first time, activity after that: a project told about an
  # observation hears about a confirming or disagreeing identification
  # on it as activity, not as something new.
  def self.kind_for(project, external_site, observation_id)
    told = exists?(project: project, external_site: external_site,
                   remote_observation_id: observation_id)
    told ? OTHER_ACTIVITY : NEW_OBSERVATION
  end

  # An observation imported from a site carries that site's id for it,
  # so a project told about it there does not hear about it again as a
  # find here.
  #
  # A comment is no find either: what makes an observation the
  # project's business is a watched name arriving on it, not somebody
  # talking about it.
  def self.local_kind_for(project, observation, target = nil)
    return OTHER_ACTIVITY if target.is_a?(Comment)

    told_about(project, observation).exists? ? OTHER_ACTIVITY : NEW_OBSERVATION
  end

  # What this project has been told about this observation, whichever
  # source said so.
  def self.told_about(project, observation)
    local = where(project: project, observation: observation)
    remote = remote_rows(project, observation)
    remote ? local.or(remote) : local
  end

  # The last thing it was told, which is where the watched name comes
  # from when later activity is reported. Nil when it has heard
  # nothing.
  def self.last_alert_for(project, observation)
    told_about(project, observation).order(:id).last
  end

  # A remote id means something only with the site that issued it, so
  # each link is matched against its site. No link, no clause: a row
  # carrying no remote id is not about this observation.
  #
  # Queried rather than read off the observation, whose association
  # may have been loaded before the link it needs existed.
  def self.remote_rows(project, observation)
    ExternalLink.where(target: observation).includes(:external_site).
      filter_map { |link| remote_row(project, link) }.
      reduce { |rows, clause| rows.or(clause) }
  end

  def self.remote_row(project, link)
    id = link.site_record_id
    return nil if id.blank?

    where(project: project, external_site_id: link.external_site_id,
          remote_observation_id: id)
  end

  # Whichever source this came from, this is where to read it.
  def url
    return external_site&.observation_url(remote_observation_id) if
      external_site_id

    "#{MO.http_domain}/obs/#{observation_id}"
  end

  # Kept for the iNaturalist cycle, which asks about the site's copy.
  def remote_url
    external_site&.observation_url(remote_observation_id)
  end

  def source_name
    external_site&.name || :app_title.l
  end

  # What groups rows about one observation in a message: the site's id
  # for it, or ours.
  def observation_key
    if external_site_id
      [external_site_id,
       remote_observation_id]
    else
      observation_id
    end
  end

  def new_observation?
    kind == NEW_OBSERVATION
  end

  # What happened, for a row of an activity message: a coordinator
  # told that something changed wants to know what. A proposal names
  # what was proposed; otherwise the answer is what the name did,
  # against the name this project was last told. Nil for a find,
  # whose message already says an observation arrived.
  def activity_phrase
    return nil unless kind == OTHER_ACTIVITY
    return :email_project_alert_what_comment.l if target_type == "Comment"
    return :email_project_alert_what_naming.l(name: proposed_name) if
      proposal?

    name_change_phrase
  end

  # What groups alerts into messages: one message per watched name per
  # kind, so a subject line can name the taxon.
  def message_key
    [kind, target_name.to_s]
  end

  private

  # A naming of something the observation does not carry: nothing
  # has moved yet, and what somebody proposed is the news. A Naming
  # since destroyed names nothing, and falls through to what the
  # name did.
  def proposal?
    proposed_name.present? && proposed_name != name
  end

  def proposed_name
    return @proposed_name if defined?(@proposed_name)

    @proposed_name = target_type == "Naming" ? target&.name&.text_name : nil
  end

  # What the name did, against the name this project was last told.
  # A site row carries one name and cannot say by itself whether an
  # identification agreed or moved it; the row before it holds the
  # answer, for either source. Only a naming or an identification
  # confirms a name -- an observation saved with its name unchanged
  # has nothing to report, and its row stays as it was.
  def name_change_phrase
    previous = previously_alerted_name
    return nil if previous.blank?
    return :email_project_alert_what_changed_from.l(name: previous) if
      previous != name
    return nil unless target_type == "Naming" || external_site_id

    :email_project_alert_what_confirmed.l
  end

  def previously_alerted_name
    earlier_rows.order(:id).last&.name
  end

  def earlier_rows
    rows = if external_site_id
             self.class.where(project_id: project_id,
                              external_site_id: external_site_id,
                              remote_observation_id: remote_observation_id)
           else
             self.class.told_about(project, observation)
           end
    id ? rows.where(self.class[:id].lt(id)) : rows
  end

  # A row says what it alerted on, whichever source it came from.
  def names_what_it_alerted_on
    return if external_site_id && remote_identification_id.present? &&
              remote_observation_id.present?
    return if external_site_id.nil? && observation_id && target

    errors.add(:base, :project_alert_incomplete)
  end
end

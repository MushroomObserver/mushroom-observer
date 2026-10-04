# frozen_string_literal: true

#
#  = Project External Site
#
#  A project's relationship with one external site (#5416): where its
#  observations may come from there, and what MO may do about them.
#
#  A site admin creates the row, which is what makes the arrangement
#  permitted -- there is no separate approval step. The row has two
#  source shapes, and a project may set either or both:
#
#  remote_project_id::  the site's own identifier for a sister
#                       collection, e.g. an iNat project id. Curated
#                       membership is what makes it selective, which is
#                       what a foray needs -- its box is a whole state.
#  use_constraints::    consider only observations meeting the project's
#                       constraints -- whichever of target names, target
#                       locations, the area of its location and its
#                       dates it sets. Target names are what make it
#                       selective, which is what a rare challenge has.
#
#  Separately, two flags say what to do with whatever the site returns:
#
#  alerting::   notify project admins when a candidate appears
#  importing::  bring candidates into MO
#
#  == Instance methods
#
#  configured?::   at least one source shape is set
#  acting?::       alerting or importing, so the cycle should look at it
#  remote_url::    the sister collection's page on the site
#
class ProjectExternalSite < AbstractModel
  belongs_to :project
  belongs_to :external_site

  serialize :alert_recipient_ids, coder: JSON
  after_initialize :ensure_alert_recipient_ids_initialized

  validates :external_site_id,
            uniqueness: { scope: :project_id,
                          message: :project_site_duplicate_site.t }
  validates :import_limit,
            numericality: { only_integer: true, greater_than: 0 }
  validates :remote_project_id, length: { maximum: 100 }

  validate :acting_needs_a_source
  validate :alerting_needs_a_recipient

  scope :alerting, -> { where(alerting: true) }
  scope :importing, -> { where(importing: true) }
  scope :acting, -> { where(alerting: true).or(where(importing: true)) }

  def configured?
    remote_project_id.present? || use_constraints?
  end

  def acting?
    alerting? || importing?
  end

  # iNat serves a project's page by id as well as by slug, so the id MO
  # stores is enough to link to it.
  def remote_url
    return nil if remote_project_id.blank?

    "#{Inat::Constants::SITE}/projects/#{remote_project_id}"
  end

  # Who hears about a candidate. Nobody until somebody is named: being
  # an admin of a project is not a request to be told what iNaturalist
  # identified overnight.
  def alert_recipients
    return User.none if alert_recipient_ids.blank?

    User.where(id: alert_recipient_ids)
  end

  # The logins behind the stored ids, for the form to show and take back.
  def alert_recipient_logins
    alert_recipients.map(&:login).join(", ")
  end

  # Takes what a site admin typed, so an unknown login is a form error
  # rather than a silently dropped recipient.
  def alert_recipient_logins=(value)
    logins = value.to_s.split(",").map(&:strip).compact_blank.uniq
    found = User.where(login: logins).to_a
    @unknown_recipient_logins =
      logins.reject { |l| found.any? { |u| u.login.casecmp?(l) } }
    self.alert_recipient_ids = found.map(&:id)
  end

  private

  def acting_needs_a_source
    return unless acting?
    return if configured?

    errors.add(:base, :project_site_needs_a_source)
  end

  # Alerting with nobody to alert is a setting that does nothing, and
  # looks on the page like it is working.
  def alerting_needs_a_recipient
    if @unknown_recipient_logins.present?
      errors.add(:base, :project_site_unknown_recipients,
                 logins: @unknown_recipient_logins.join(", "))
    end
    return unless alerting?
    return if alert_recipient_ids.present?

    errors.add(:base, :project_site_needs_a_recipient)
  end

  def ensure_alert_recipient_ids_initialized
    self.alert_recipient_ids ||= [] if has_attribute?(:alert_recipient_ids)
  end
end

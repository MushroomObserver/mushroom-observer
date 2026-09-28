# frozen_string_literal: true

#
#  = Project External Source
#
#  Where a project's observations may come from on an external site, and
#  what MO may do about them (#5416).
#
#  A source has two shapes, and a project may set either or both:
#
#  remote_project_id::  the site's own identifier for a sister collection,
#                       e.g. an iNat project id. Curated membership is
#                       what makes it selective, which is what a foray
#                       needs -- its box is a whole state.
#  use_criteria::       derive the query from what the project already
#                       declares: target names, target locations, the box
#                       on its location, and its dates. Target names are
#                       what make it selective, which is what a rare
#                       challenge has.
#
#  Separately, two flags say what to do with whatever the source returns:
#
#  alerting::   notify project admins when a candidate appears
#  importing::  bring candidates into MO
#
#  Neither may be set until a site admin approves the project, and an
#  approved project may still import no more than +import_limit+
#  observations over its lifetime.
#
#  == Instance methods
#
#  approved?::    a site admin has approved this project
#  configured?::  at least one source shape is set
#  acting?::      alerting or importing, so the cycle should look at it
#  approve::      record approval by a site admin
#  revoke::       withdraw approval, turning both flags off
#
class ProjectExternalSource < AbstractModel
  belongs_to :project
  belongs_to :external_site
  belongs_to :approved_by, class_name: "User", optional: true

  validates :external_site_id,
            uniqueness: { scope: :project_id,
                          message: :project_source_duplicate_site.t }
  validates :import_limit,
            numericality: { only_integer: true, greater_than: 0 }
  validates :remote_project_id, length: { maximum: 100 }

  validate :acting_needs_a_source
  validate :acting_needs_approval

  scope :approved, -> { where.not(approved_at: nil) }
  scope :alerting, -> { where(alerting: true) }
  scope :importing, -> { where(importing: true) }
  scope :acting, -> { where(alerting: true).or(where(importing: true)) }

  def approved?
    approved_at.present?
  end

  def configured?
    remote_project_id.present? || use_criteria?
  end

  def acting?
    alerting? || importing?
  end

  def approve(admin)
    update(approved_at: Time.zone.now, approved_by: admin)
  end

  # Withdrawing approval turns the flags off rather than leaving them set
  # but inert, so that what the row says and what MO will do stay the
  # same thing.
  def revoke
    update(approved_at: nil, approved_by: nil,
           alerting: false, importing: false)
  end

  private

  def acting_needs_a_source
    return unless acting?
    return if configured?

    errors.add(:base, :project_source_needs_a_source)
  end

  def acting_needs_approval
    return unless acting?
    return if approved?

    errors.add(:base, :project_source_needs_approval)
  end
end

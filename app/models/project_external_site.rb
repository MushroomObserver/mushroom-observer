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
#  Separately, one flag says what to do with whatever the site
#  returns:
#
#  importing::  bring candidates into MO
#
#  Alerting is a question about the project, not about one of its
#  sources (#5721): an admin subscribes once, on the project, and
#  hears about a match whichever source found it.
#
#  == Instance methods
#
#  configured?::   at least one source shape is set
#  acting?::       the project alerts, or this site imports, so the
#                  cycle should look at it
#  remote_url::    the sister collection's page on the site
#
class ProjectExternalSite < AbstractModel
  belongs_to :project
  belongs_to :external_site

  validates :external_site_id,
            uniqueness: { scope: :project_id,
                          message: ->(*) { :project_site_duplicate_site.t } }
  validates :import_limit,
            numericality: { only_integer: true, greater_than: 0 }
  validates :remote_project_id, length: { maximum: 100 }

  validate :importing_needs_a_source

  scope :importing, -> { where(importing: true) }
  scope :acting, lambda {
    where(importing: true).or(where(project: Project.alerting))
  }

  def configured?
    remote_project_id.present? || use_constraints?
  end

  def acting?
    project.alerting? || importing?
  end

  # iNat serves a project's page by id as well as by slug, so the id MO
  # stores is enough to link to it.
  def remote_url
    return nil if remote_project_id.blank?

    "#{Inat::Constants::SITE}/projects/#{remote_project_id}"
  end

  private

  def importing_needs_a_source
    return unless importing?
    return if configured?

    errors.add(:base, :project_site_needs_a_source)
  end
end

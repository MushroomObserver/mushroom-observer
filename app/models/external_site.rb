# frozen_string_literal: true

#
#  = External Site Model
#
#  == Attributes
#
#  id::            Locally unique numerical id, starting at 1.
#  name::          Name of website, e.g. "MycoPortal".
#  project::       Project which talks about the website and whose members
#                  may edit external_links to this site for any observation.
#
class ExternalSite < AbstractModel
  belongs_to :project
  has_many   :external_links
  has_many   :observations, through: :external_links

  validates :project, presence: true
  validates :name,    presence: true, length: { maximum: 100 },
                      uniqueness: { case_sensitive: false }

  scope :order_by_default,
        -> { order_by(::Query::ExternalSites.default_order) }
  scope :name_has,
        ->(phrase) { search_columns(ExternalSite[:name], phrase) }

  def member?(user)
    user.in_group?(project.user_group)
  end

  # Either the observer, an admin, or a member of a project for a specific site
  # can add an external link. We only permit one link per external site per obs.
  def self.sites_user_can_add_links_to(user, obs, admin: false)
    return [] unless obs && user

    obs_site_ids = obs.external_links.map(&:external_site_id)
    if (user == obs.user) || admin
      where.not(id: obs_site_ids)
    else
      where(project: user.projects_member).where.not(id: obs_site_ids)
    end
  end
end

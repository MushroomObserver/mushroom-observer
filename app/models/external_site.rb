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
  validates :name,    presence: true, length: { maximum: 100 }, uniqueness: true

  def member?(user)
    user.in_group?(project.user_group)
  end
end

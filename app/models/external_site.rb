# frozen_string_literal: true

#
#  = External Site Model
#
#  == Attributes
#
#  id::            Locally unique numerical id, starting at 1.
#  name::          Name of website, e.g. "MyCoPortal".
#  project::       Project which talks about the website and whose members
#                  may edit external_links to this site for any observation.
#
class ExternalSite < AbstractModel
  INATURALIST_NAME = "iNaturalist"
  MYCOPORTAL_NAME = "MyCoPortal"

  belongs_to :project
  has_many   :external_links
  has_many   :observations, through: :external_links

  validates :name, presence: true, length: { maximum: 100 },
                   uniqueness: { case_sensitive: false }
  validates :base_url, presence: true, uniqueness: { case_sensitive: false }
  validate  :check_url_syntax
  before_validation :format_base_url

  scope :order_by_default,
        -> { order_by(::Query::ExternalSites.default_order) }
  scope :name_has,
        ->(phrase) { search_columns(ExternalSite[:name], phrase) }

  scope :user_is_site_project_member, lambda { |user|
    user_id = user.is_a?(Integer) ? user : user&.id

    where(project: Project.user_is_member(user_id))
  }

  def check_url_syntax
    return if format_base_url

    errors.add(:base_url, :validate_invalid_url.t)
  end

  def format_base_url
    test_url = FormatURL.new(base_url)
    return false unless test_url.valid?

    self.base_url = test_url.formatted
    base_url
  end

  # The iNaturalist site row, seeded by fixtures/migration. Cheap lookup
  # by indexed unique name.
  def self.inaturalist
    find_by!(name: INATURALIST_NAME)
  end

  # The MyCoPortal site row, seeded by fixtures/migration. Cheap lookup
  # by indexed unique name.
  def self.mycoportal
    find_by!(name: MYCOPORTAL_NAME)
  end

  # URL of the per-record page on this site for the given external_id
  # (#4299). Built from `url_template` with its `{id}` placeholder
  # substituted; falls back to appending the id to `base_url` when no
  # template is set (correct for iNat, whose base_url is the per-obs path).
  # This is the single source of truth for an ExternalLink's URL — links
  # store only `external_id`, not the full URL.
  def observation_url(external_id)
    template = url_template.presence || "#{base_url}{id}"
    template.sub("{id}", external_id.to_s)
  end

  # Reverse of #observation_url: given a URL this site actually
  # produced, extract whatever filled the `{id}` placeholder --
  # e.g. "1950183" out of MyCoPortal's
  # ".../index.php?occid=1950183", or the bare id out of iNat's
  # base_url-only template. nil if the url doesn't have this site's
  # template shape (or the template has no `{id}` at all).
  def id_from_url(url)
    return nil if url.blank?

    template = url_template.presence || "#{base_url}{id}"
    # -1 limit: {id} is usually the last token, and split drops trailing
    # empty strings by default -- losing the empty string after it means
    # losing the capture group meant to go there.
    pattern = template.split("{id}", -1).
              map { |part| Regexp.escape(part) }.join("(.+)")
    /\A#{pattern}\z/.match(url)&.captures&.first
  end

  def member?(user)
    return false unless project

    user.in_group?(project.user_group)
  end

  # Either the observer, an admin, or a member of a project for a specific site
  # can add an external link. We only permit one link per external site per obs.
  def self.sites_user_can_add_links_to_for_obs(user, obs, admin: false)
    return [] unless obs && user

    # Multiple links per site are allowed (#4565), so don't exclude sites
    # the obs already links to.
    if (user == obs.user) || admin
      all
    else
      user_is_site_project_member(user.id)
    end
  end
end

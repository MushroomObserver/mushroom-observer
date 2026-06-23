# frozen_string_literal: true

#
#  = External Link Model
#
#  An external link is a URL attached to a single observation which links to a
#  related record on an external site.  It is associated with a record in the
#  external_sites table, which potentially eventually among other things, tells
#  the site who is allowed to create external links to that site.  It is
#  important to note that only the owner of an observation and users associated
#  with an external_site (via an external_site's project's member user_group)
#  are allowed to attach a URL for that external_site to that observation.
#
#  (Wow, that was difficult to write...)
#
#  == Attributes
#
#  id::            Locally unique numerical id, starting at 1.
#  created_at::    Date/time it was first created.
#  updated_at::    Date/time it was last updated.
#  user::          User that created it.
#  observation::   Observation the URL is attached to.
#  external_site:: External site the URL points to.
#  url::           Actual URL, complete with transport ("http://"), etc.
#
class ExternalLink < AbstractModel
  # The kind of relationship this link records between the target and the
  # external site (#4299/#4565). Drives the Show-page credit wording (the
  # site name comes from ExternalSite):
  #   manual  — a user hand-linked the obs            "Manual link to <site>"
  #   import  — MO created the obs from the source     "Imported from <site>"
  #   export  — (future) MO pushes the obs out         "Exported to <site>"
  #   mirror  — MO mirrored its native obs to source   "Mirrored to <site>"
  #   copy    — the source copied/back-referenced it   "Copied by <site>"
  #   unknown — link exists, type unrecorded           "Linked to <site>"
  # `manual` (0) is the default — pre-existing rows are user-added links.
  # `import` marks the external source the target was imported from — at most
  # one per target (enforced below and by a DB unique index on a generated
  # column). Only 0/1 were ever in production, so 2-5 are free to define.
  enum :relationship,
       { manual: 0, import: 1, export: 2, mirror: 3, copy: 4, unknown: 5 },
       default: :manual

  # Polymorphic so a link can attach to an Observation or an Image (per-photo
  # import provenance, #4529) — one model, one code path (#4299).
  belongs_to :target, polymorphic: true
  belongs_to :external_site
  # NOTE: (future, #4529 image-provenance work): imports/exports and verified
  # provenance should set user to the admin user (id=0), not the importer;
  # once everything is admin-owned the user_id column may be droppable. Not
  # changed as part of #4299.
  belongs_to :user

  validates :target, presence: true
  # Uniqueness is on the column, not the polymorphic association (Rails can't
  # compute the class for a polymorphic uniqueness check).
  validates :target_id,
            uniqueness: { scope: [:target_type, :external_site_id] }
  validates :external_site, presence: true
  validates :user, presence: true
  validates :url, length: { maximum: 100 }, allow_blank: true
  validate  :check_url_syntax
  validate  :only_one_import_per_target, if: :import?
  before_validation :format_url_for_external_site

  scope :order_by_default,
        -> { order_by(::Query::ExternalLinks.default_order) }
  scope :url_has,
        ->(phrase) { search_columns(ExternalLink[:url], phrase) }
  scope :external_sites, lambda { |sites|
    ids = Lookup::ExternalSites.new(sites).ids
    where(external_site_id: ids)
  }
  scope :observations,
        ->(ids) { where(target_type: "Observation", target_id: ids) }

  # Eager-loads the show/edit page: user, polymorphic target, and the
  # external site (rendered as a link). The target is loaded shallowly — a
  # polymorphic association can't nest a per-type subtree in `includes`, so
  # a consumer that needs the target's own associations (e.g. the edit
  # page's matrix-box card) loads the typed record separately with its own
  # includes (see Observations::ExternalLinksController#set_ivars_for_edit).
  # That keeps this scope strict-loaded.
  def self.show_includes_tree
    [:user, :target, { external_site: { project: :user_group } }]
  end

  def self.index_includes_tree
    show_includes_tree
  end

  scope :show_includes, -> { strict_loading.includes(show_includes_tree) }
  scope :index_includes, -> { strict_loading.includes(index_includes_tree) }

  def check_url_syntax
    return if url.blank? || format_url_for_external_site

    errors.add(:url, :validate_invalid_url.t)
  end

  # A target has at most one import link (its authoritative external
  # source). A DB unique index on a generated column also guards this; the
  # validation produces a friendly error instead of RecordNotUnique.
  def only_one_import_per_target
    others = ExternalLink.import.where(target_type: target_type,
                                       target_id: target_id)
    others = others.where.not(id: id) if id
    return unless others.exists?

    errors.add(:relationship, :validate_one_import_per_target.t)
  end

  def format_url_for_external_site
    return true if url.blank?
    return false unless (base_url = external_site&.base_url)
    return inat_url?(base_url) if external_site.name == "iNaturalist"

    test_url = FormatURL.new(url, base_url)
    return false unless test_url.valid?

    self.url = test_url.formatted
    url
  end

  # iNaturalist's Cloudflare CDN blocks automated HEAD requests with 403,
  # causing FormatURL#url_exists? to fail. Skip the reachability check,
  # validating the URL format against a regexp instead.
  def inat_url?(base_url)
    url.to_s.match?(/\A#{Regexp.escape(base_url)}\d+\z/) && url
  end

  # Convenience function to allow +sort_by(&:site_name)+.
  def site_name
    external_site.name
  end

  # Backward-compat for the observation-only manual-link feature
  # (external_links_controller, Query, views). Manual cross-reference links
  # are always observation-targeted; image links exist only as import
  # provenance and never flow through these readers/writers.
  def observation
    target if target_type == "Observation"
  end

  def observation_id
    target_id if target_type == "Observation"
  end

  def observation=(obs)
    self.target = obs
  end

  # The display URL: the stored override if present, else derived from the
  # site's url_template + external_id (#4299). Import links store no url.
  def link_url
    url.presence || external_site&.observation_url(external_id)
  end

  def can_edit?(user)
    return false unless user

    user.id == target&.user_id ||
      external_site&.project&.member?(user)
  end

  def self.show_controller; end
  def self.show_action; end
  def self.edit_action; end
  def self.index_action; end
  def self.show_url(id); end
  def self.show_link_args(id); end
end

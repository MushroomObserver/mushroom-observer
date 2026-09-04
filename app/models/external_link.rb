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
#  external_id::   This link's id on the external site -- the URL is
#                  derived on demand via #link_url. Required for every
#                  relationship except :export, where it is unknown
#                  until the external site assigns one (see #5315).
#
class ExternalLink < AbstractModel
  # The kind of relationship this link records between the target and the
  # external site (#4299/#4565). Drives the Show-page credit wording (the
  # site name comes from ExternalSite):
  #   manual        — user linked it on MO    "Manual link to <site>"
  #   remote_manual — user linked it on site  "Manual link from <site>"
  #   import  — MO created the obs from the source     "Imported from <site>"
  #   export  — (future) MO pushes the obs out         "Exported to <site>"
  #   mirror  — MO mirrored its native obs to source   "Mirrored to <site>"
  #   copy    — the source's bulk service copied it    "Copied by <site>"
  #   unknown — link exists, type unrecorded           "Linked to <site>"
  # `manual` (0) is the default — pre-existing rows are MO-side user links.
  # `import` marks the external source the target was imported from — at most
  # one per target (enforced below and by a DB unique index on a generated
  # column). Only 0/1 were ever in production, so 2-6 are free to define.
  enum :relationship,
       { manual: 0, import: 1, export: 2, mirror: 3, copy: 4, unknown: 5,
         remote_manual: 6 },
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
  validates :external_site, presence: true
  validates :user, presence: true
  # Matches the column's varchar(64); without this a long paste 500s
  # with ActiveRecord::ValueTooLong instead of a form error.
  validates :external_id, length: { maximum: 64 }
  # Every other relationship identifies a specific record on the external
  # site, so external_id is required. An export link is created before
  # the external site has assigned one -- see issue #5315.
  validates :external_id, presence: true, unless: :export?
  # No general one-link-per-(target, site) rule: an MO obs can legitimately
  # correspond to several iNat obs (iNat-side duplicates of one collection),
  # so it may carry multiple iNat links (#4565). Only one IMPORT (reflection)
  # per target is still enforced (below + the import_target unique index).
  validate  :only_one_import_per_target, if: :import?
  before_validation :resolve_submitted_external_id

  scope :order_by_default,
        -> { order_by(::Query::ExternalLinks.default_order) }
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

  # A target has at most one import link (its authoritative external
  # source). A DB unique index on a generated column also guards this; the
  # validation produces a friendly error instead of RecordNotUnique.
  def only_one_import_per_target
    others = ExternalLink.import.where(target_type: target_type,
                                       target_id: target_id)
    others = others.where.not(id: id) if id
    return unless others.exists?

    errors.add(:relationship, :validate_one_import_per_target)
  end

  # `external_id` accepts either a bare site id or a url pasted from the
  # external site -- resolves the latter to a bare id via the site's
  # known shapes before validation, so a pasted permalink doesn't sit
  # unresolved (there's no url column left to hold it in). A url shape
  # that needs a live crawl to resolve, or that doesn't match this
  # site's format, fails validation instead of storing the raw url as
  # if it were an id.
  def resolve_submitted_external_id
    return if external_id.blank? || external_site.blank?
    return unless external_id.include?("://")

    resolved = external_site.id_from_url(external_id)
    return self.external_id = resolved if resolved

    reject_unresolvable_url
  end

  def reject_unresolvable_url
    if external_site.mycoportal_list_search?(external_id)
      errors.add(:external_id, :validate_external_link_list_search_url)
    elsif ExternalLink.self_referential_url?(external_id)
      errors.add(:external_id, :validate_external_link_self_referential_url,
                 site: external_site.name)
    else
      errors.add(:external_id, :validate_external_link_unrecognized_url,
                 site: external_site.name)
    end
  end

  # Convenience function to allow +sort_by(&:site_name)+.
  def site_name
    external_site.name
  end

  # Best estimate of when this relationship arose, for display next to the
  # link. When we know the external record's creation date the relationship
  # can only exist once both records do, so use the later of (external record,
  # our target). Otherwise (imports, legacy manual cross-refs) fall back to
  # when the link row itself was created.
  def relationship_date
    if external_created_on && target
      [external_created_on, target.created_at.to_date].max
    else
      # created_at is nil only for unsaved records (saved links always have one)
      created_at&.to_date
    end
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

  # The display URL, derived from the site's url_template + external_id
  # (#4299).
  def link_url
    external_site&.observation_url(external_id)
  end

  # This link's id on the external site, when the site is iNaturalist --
  # nil for every other site.
  def inaturalist_id
    return nil unless external_site&.name == ExternalSite::INATURALIST_NAME

    external_id
  end

  # Same as #inaturalist_id, for MyCoPortal.
  def mycoportal_id
    return nil unless external_site&.name == ExternalSite::MYCOPORTAL_NAME

    external_id
  end

  # This link's id on its external site, for whichever site has an id
  # accessor above -- nil for a site with none. The one caller that
  # cares (Components::Link::External, for the copy-to-clipboard
  # IDBadge) doesn't need to know which site it is to ask for its id.
  def site_record_id
    inaturalist_id || mycoportal_id
  end

  def can_edit?(user)
    return false unless user

    user.id == target&.user_id ||
      external_site&.project&.member?(user)
  end

  # Anchored to the start of the url, not just on "://mushroomobserver.org"
  # -- an unanchored match would also catch a third-party url that merely
  # carries a full MO url in a query value (e.g.
  # "https://evil.example/track?next=https://mushroomobserver.org/N").
  # Not matched on `uri.host` either, since a malformed double-scheme
  # url like "http://https://mushroomobserver.org/N" parses with host
  # "https", not the intended host -- the optional extra "https://"
  # right after the scheme covers that case instead.
  SELF_REFERENTIAL_RE =
    %r{\Ahttps?://(?:https://)?(?:www\.)?mushroomobserver\.org(/|\z)}

  # True when url points back at MushroomObserver -- a stray paste, or
  # the linked target's MO url pasted in by mistake.
  def self.self_referential_url?(url)
    url == "http://adolf" || url.match?(SELF_REFERENTIAL_RE)
  end

  def self.show_controller; end
  def self.show_action; end
  def self.edit_action; end
  def self.index_action; end
  def self.show_url(id); end
  def self.show_link_args(id); end
end

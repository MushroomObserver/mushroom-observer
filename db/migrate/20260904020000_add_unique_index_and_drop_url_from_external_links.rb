# frozen_string_literal: true

# #4592/#5312: external_id becomes the identity for a resolved
# ExternalLink; url is derived on demand via ExternalSite#observation_url
# (ExternalLink#link_url). external_id stays nullable -- an export-batch
# marker link legitimately has none until MyCoPortal assigns one (see
# issue #5315) -- so this migration does not add a NOT NULL constraint.
# Requires resolve_mycoportal_links.rb and
# backfill_inaturalist_external_ids.rb (see script/run-once/README.md --
# neither is committed here) to have run --apply against production
# first, so every resolvable link is resolved before the unique index
# goes on.
class AddUniqueIndexAndDropURLFromExternalLinks < ActiveRecord::Migration[7.2]
  KEY_COLUMNS = [
    :target_type, :target_id, :external_site_id, :external_id
  ].freeze

  def change
    # Exact-duplicate backstop (#4592). Multiple links per (target, site)
    # stay allowed (#4565) as long as they carry different external_ids.
    # MySQL treats each NULL as distinct, so export-batch marker links
    # with no external_id yet do not collide with each other here.
    #
    # Remove any exact duplicates first so the index can't abort on
    # pre-existing dupes regardless of whether the run-once prep scripts
    # above have run. Idempotent (a no-op once they have). Keeps the
    # oldest row in each group -- for a mixed-relationship duplicate that
    # is the original import/provenance link.
    reversible do |dir|
      dir.up { remove_duplicate_external_links }
    end

    add_index(:external_links,
              [:target_type, :target_id, :external_site_id, :external_id],
              unique: true,
              name: "index_external_links_on_target_and_site_and_extid")

    remove_column(:external_links, :url, :string, limit: 100)
  end

  private

  def remove_duplicate_external_links
    ExternalLink.group(*KEY_COLUMNS).having(Arel.star.count.gt(1)).count.
      each_key { |values| dedupe_group(KEY_COLUMNS.zip(values).to_h) }
  end

  def dedupe_group(conditions)
    ids = ExternalLink.where(conditions).order(:id).pluck(:id)
    extra = ids.drop(1)
    return if extra.empty?

    say("Removing #{extra.size} duplicate external_link(s): #{extra.inspect}")
    ExternalLink.where(id: extra).delete_all
  end
end

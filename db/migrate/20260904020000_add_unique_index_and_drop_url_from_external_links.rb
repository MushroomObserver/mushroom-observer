# frozen_string_literal: true

# #4592/#5312: external_id becomes the identity for a resolved
# ExternalLink; url is derived on demand via ExternalSite#observation_url
# (ExternalLink#link_url). external_id stays nullable -- an export-batch
# marker link legitimately has none until MyCoPortal assigns one (see
# issue #5315) -- so this migration does not add a NOT NULL constraint.
# Requires script/resolve_mycoportal_links.rb and
# script/backfill_inaturalist_external_ids.rb to have run --apply against
# production first, so every resolvable link is resolved before the
# unique index goes on.
class AddUniqueIndexAndDropURLFromExternalLinks < ActiveRecord::Migration[7.2]
  def change
    # Exact-duplicate backstop (#4592). Multiple links per (target, site)
    # stay allowed (#4565) as long as they carry different external_ids.
    # MySQL treats each NULL as distinct, so export-batch marker links
    # with no external_id yet do not collide with each other here.
    add_index(:external_links,
              [:target_type, :target_id, :external_site_id, :external_id],
              unique: true,
              name: "index_external_links_on_target_and_site_and_extid")

    remove_column(:external_links, :url, :string, limit: 100)
  end
end

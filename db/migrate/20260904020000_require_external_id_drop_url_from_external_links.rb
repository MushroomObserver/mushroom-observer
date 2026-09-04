# frozen_string_literal: true

# #4592/#5312: external_id becomes the single source of identity for an
# ExternalLink; url is derived on demand via ExternalSite#observation_url
# (ExternalLink#link_url). Requires script/resolve_mycoportal_links.rb
# and script/backfill_inaturalist_external_ids.rb to have run --apply
# against production first -- this migration fails loudly (no default
# backfill) if any row still has a nil external_id when it runs.
class RequireExternalIDDropURLFromExternalLinks < ActiveRecord::Migration[7.2]
  def change
    change_column_null(:external_links, :external_id, false)

    # Exact-duplicate backstop now that external_id is always present.
    # Multiple links per (target, site) stay allowed (#4565) as long as
    # they carry different external_ids.
    add_index(:external_links,
              [:target_type, :target_id, :external_site_id, :external_id],
              unique: true,
              name: "index_external_links_on_target_and_site_and_extid")

    remove_column(:external_links, :url, :string, limit: 100)
  end
end

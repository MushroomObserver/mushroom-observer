# frozen_string_literal: true

# Phase 1 (additive) of consolidating Source into the ExternalLink
# relationship model (#4299). The data backfill runs separately as
# script/backfill_external_links_from_sources.rb; the old Source columns +
# table are dropped in a follow-up phase-2 migration.
#
# ExternalLink becomes polymorphic so it can attach to observations AND
# images (per-photo provenance, #4529) — one model, one code path:
# - external_links.observation_id -> target_id + target_type.
# - + external_id (the platform's stable per-record id; canonical for sync
#   and dedup), relationship enum (default 0 = cross_reference, the
#   historical meaning of existing rows), last_synced_at.
# - url becomes derived: ExternalSite#observation_url builds it from the new
#   external_sites.url_template + external_id. The existing external_links.url
#   column stays as a nullable override for the rare site whose URL can't be
#   templated from the id; import links leave it NULL.
# - At most one import (relationship=1) per target: a stored generated column
#   (NULL for non-import rows) + a unique index. MySQL has no partial index,
#   but InnoDB treats the NULLs as non-conflicting.
class AddRelationshipModelToExternalLinks < ActiveRecord::Migration[7.2]
  IMPORT_TARGET =
    "(CASE WHEN relationship = 1 " \
    "THEN CONCAT(target_type, ':', target_id) END)"

  def up
    change_table(:external_sites, bulk: true) do |t|
      t.text(:description)
      t.datetime(:last_successful_sync_at)
      t.string(:url_template)
    end

    rename_column(:external_links, :observation_id, :target_id)

    change_table(:external_links, bulk: true) do |t|
      t.string(:target_type, limit: 64)
      t.string(:external_id, limit: 64)
      t.integer(:relationship, null: false, default: 0)
      t.datetime(:last_synced_at)
      t.virtual(:import_target, type: :string, stored: true, as: IMPORT_TARGET)
      t.index(:import_target, unique: true,
                              name: "index_external_links_on_import_target")
      t.index([:external_site_id, :relationship, :target_type, :external_id],
              name: "index_external_links_on_site_rel_target_extid")
      t.index([:target_type, :target_id],
              name: "index_external_links_on_target")
    end

    execute(<<~SQL.squish)
      UPDATE external_links SET target_type = 'Observation'
      WHERE target_type IS NULL
    SQL
  end

  def down
    change_table(:external_links, bulk: true) do |t|
      t.remove_index(name: "index_external_links_on_site_rel_target_extid")
      t.remove_index(name: "index_external_links_on_target")
      t.remove(:external_id, :relationship, :last_synced_at, :import_target,
               :target_type)
    end
    rename_column(:external_links, :target_id, :observation_id)

    change_table(:external_sites, bulk: true) do |t|
      t.remove(:description, :last_successful_sync_at, :url_template)
    end
  end
end

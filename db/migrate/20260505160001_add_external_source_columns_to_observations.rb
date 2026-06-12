# frozen_string_literal: true

# Adds the generic external-source columns to `observations`:
#
# - `source_id` (FK to `sources`) — which external system the
#   observation was imported from (NULL for native MO observations).
# - `external_id` (string) — the source system's stable identifier
#   for this observation (e.g., the iNat observation number).
# - `last_synced_at` (datetime) — set by the sync job (#4215) when it
#   refreshes data from the source. NULL until first sync.
#
# Uniqueness on `(source_id, external_id)` prevents duplicate
# imports of the same source observation. The index is partial in
# spirit (only meaningful when both are non-null) but MySQL doesn't
# support partial indexes — fortunately the unique constraint on a
# pair containing NULL is treated as non-conflicting by InnoDB, so
# a plain unique index does the right thing here.
class AddExternalSourceColumnsToObservations < ActiveRecord::Migration[7.2]
  def change
    add_reference(:observations, :source,
                  foreign_key: { to_table: :sources },
                  null: true,
                  index: false)
    add_column(:observations, :external_id, :string, limit: 64)
    add_column(:observations, :last_synced_at, :datetime)
    # Composite index doubles as the lookup index for source_id alone
    # (leftmost-prefix), so no separate source_id index is needed.
    add_index(:observations, [:source_id, :external_id],
              unique: true,
              name: "index_observations_on_source_id_and_external_id")
  end
end

# frozen_string_literal: true

# Backfills the new external-source columns for every observation
# that links to an iNat record via the legacy `inat_id` column.
#
# Before this migration: most iNat-linked observations carried
# `source = 5` (the `mo_inat_import` enum value) and their iNat
# observation number in `inat_id`. A small number of rows had a
# non-import entry-agent (e.g. `mo_website`) but were nonetheless
# linked to an iNat record through `inat_id` — typically because
# the user attached the iNat link after creating the obs natively.
#
# After this migration: every row with `inat_id IS NOT NULL`
# carries `source_id` pointing at the iNaturalist row in `sources`
# and `external_id` holding the stringified iNat observation
# number. The entry-agent column (`source`) is cleared only for
# rows that had `source = 5` — the `mo_inat_import` enum value is
# being dropped because the two-axis model in #4208 expresses
# "this is an import" through `source_id IS NOT NULL`, not the
# entry-agent column. Rows with a non-import entry agent keep it.
#
# Native MO observations without an iNat link are untouched. The
# `inat_id` column stays in place for now; a follow-up PR drops it
# once this backfill is verified in production.
class BackfillExternalSourceForInatImports < ActiveRecord::Migration[7.2]
  INAT_ENUM_VALUE = 5

  def up
    inat_source_id = select_value(<<~SQL.squish)
      SELECT id FROM sources WHERE name = 'iNaturalist'
    SQL

    raise("iNaturalist source row missing — run CreateSources first.") \
      if inat_source_id.blank?

    # Set source_id + external_id on every iNat-linked obs.
    execute(<<~SQL.squish)
      UPDATE observations
         SET source_id = #{inat_source_id},
             external_id = CAST(inat_id AS CHAR)
       WHERE inat_id IS NOT NULL
    SQL

    # Clear the entry-agent column only for the dropped enum value.
    execute(<<~SQL.squish)
      UPDATE observations
         SET source = NULL
       WHERE source = #{INAT_ENUM_VALUE}
    SQL
  end

  # Rollback is intentionally lossy. `up` cleared `source` only on
  # rows that had `source = 5`, but it doesn't record which iNat-
  # linked rows started with `source = 5` versus `source = NULL`.
  # `down` restores `source = 5` on every iNat-linked row whose
  # `source` is currently NULL — which would mis-classify any row
  # that was already `source = NULL` before `up` ran. (As of the
  # production data this affects zero rows; the only non-import
  # entry agent that ever appeared on an iNat-linked row was
  # mo_website, and that row keeps its entry agent through `up`.)
  def down
    inat_source_id = select_value(<<~SQL.squish)
      SELECT id FROM sources WHERE name = 'iNaturalist'
    SQL

    return if inat_source_id.blank?

    execute(<<~SQL.squish)
      UPDATE observations
         SET source = #{INAT_ENUM_VALUE}
       WHERE source_id = #{inat_source_id}
         AND source IS NULL
    SQL

    execute(<<~SQL.squish)
      UPDATE observations
         SET source_id = NULL,
             external_id = NULL
       WHERE source_id = #{inat_source_id}
    SQL
  end
end

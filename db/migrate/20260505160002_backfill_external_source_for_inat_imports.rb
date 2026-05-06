# frozen_string_literal: true

# Backfills the new external-source columns for existing iNat imports.
#
# Before this migration: iNat-imported observations carried
# `source = 5` (the `mo_inat_import` enum value) and their iNat
# observation number in `inat_id`.
#
# After this migration: those same rows carry `source_id` pointing
# at the iNaturalist row in `sources`, `external_id` holding the
# stringified iNat observation number, and `source = NULL`. The
# entry-agent enum no longer has an `import` value — the two-axis
# model in #4208 expresses "this is an import" through
# `source_id IS NOT NULL`, not through the entry-agent column.
#
# Native MO observations (web/android/iphone/api entries) are
# untouched. The `inat_id` column stays in place for now; a
# follow-up PR drops it once this backfill is verified in
# production.
class BackfillExternalSourceForInatImports < ActiveRecord::Migration[7.2]
  INAT_ENUM_VALUE = 5

  def up
    inat_source_id = select_value(<<~SQL.squish)
      SELECT id FROM sources WHERE name = 'iNaturalist'
    SQL

    raise("iNaturalist source row missing — run CreateSources first.") \
      if inat_source_id.blank?

    execute(<<~SQL.squish)
      UPDATE observations
         SET source_id = #{inat_source_id},
             external_id = CAST(inat_id AS CHAR),
             source = NULL
       WHERE source = #{INAT_ENUM_VALUE}
         AND inat_id IS NOT NULL
    SQL
  end

  def down
    inat_source_id = select_value(<<~SQL.squish)
      SELECT id FROM sources WHERE name = 'iNaturalist'
    SQL

    return if inat_source_id.blank?

    execute(<<~SQL.squish)
      UPDATE observations
         SET source = #{INAT_ENUM_VALUE},
             external_id = NULL,
             source_id = NULL
       WHERE source_id = #{inat_source_id}
    SQL
  end
end

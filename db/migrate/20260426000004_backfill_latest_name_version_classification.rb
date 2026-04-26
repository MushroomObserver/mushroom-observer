# frozen_string_literal: true

# One-shot backfill: copy `names.classification` into the latest
# version row of each Name. Older versions keep their NULL classification
# — they pre-date `acts_as_versioned` capturing the column (#4163) and
# the smart version browser (Phase 3 of the classification roadmap)
# will infer their values by walking up the genus chain.
#
# The latest row is special: it's the version that was current at the
# moment of this deploy, so its classification is exactly
# `names.classification` right now. That's a real fact worth keeping
# rather than losing to NULL.
class BackfillLatestNameVersionClassification < ActiveRecord::Migration[7.2]
  def up
    execute(<<~SQL.squish)
      UPDATE name_versions nv
      JOIN (SELECT name_id, MAX(version) AS max_version
            FROM name_versions
            GROUP BY name_id) latest
        ON nv.name_id = latest.name_id
       AND nv.version = latest.max_version
      JOIN names ON names.id = nv.name_id
       SET nv.classification = names.classification
      WHERE nv.classification IS NULL
        AND names.classification IS NOT NULL
    SQL
  end

  def down
    raise(ActiveRecord::IrreversibleMigration.new(
            "Backfilled rows can't be distinguished from regular " \
            "versioned writes after the fact."
          ))
  end
end

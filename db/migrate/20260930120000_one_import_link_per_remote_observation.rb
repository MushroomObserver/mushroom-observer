# frozen_string_literal: true

# One MO observation per remote observation (#5416).
#
# `already_linked?` in `Inat::ObservationImporter` reads before it
# writes, which is a gate rather than a guarantee. Two imports running
# at once -- a user importing their iNaturalist observations while a
# project import covers the same ground -- both read before either
# writes, and each creates its own MO observation for the one iNat
# record. The existing unique indexes do not catch it: one is a link
# per MO observation, the other a link per (target, site, external_id).
#
# Same shape as `import_target` above it: a stored generated column
# that is NULL for everything except an import link on an Observation,
# plus a unique index. MySQL has no partial index; InnoDB treats the
# NULLs as non-conflicting.
#
# Scoped to observations on purpose. An iNat user can attach one photo
# to two observations, and 207 photo ids in production are claimed by
# two MO images for exactly that reason, so the same constraint on
# images would be wrong. No remote observation is claimed twice today
# (0 of 78,564), so the index applies cleanly.
class OneImportLinkPerRemoteObservation < ActiveRecord::Migration[7.2]
  IMPORT_SOURCE =
    "(CASE WHEN relationship = 1 AND target_type = 'Observation' " \
    "THEN CONCAT(external_site_id, ':', external_id) END)"

  def up
    change_table(:external_links, bulk: true) do |t|
      t.virtual(:import_source, type: :string, stored: true, as: IMPORT_SOURCE)
      t.index(:import_source, unique: true,
                              name: "index_external_links_on_import_source")
    end
  end

  def down
    remove_column(:external_links, :import_source)
  end
end

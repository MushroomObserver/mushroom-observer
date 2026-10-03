# frozen_string_literal: true

# One MO record per remote record (#5416).
#
# `Inat::ObservationImporter` reads `already_linked?` before it writes,
# and `Inat::PhotoImporter` now looks for an image of the same photo
# before it uploads. Both are gates rather than guarantees: two imports
# running at once -- a user importing their iNaturalist observations
# while a project import covers the same ground -- read before either
# writes, and each builds its record for the one remote one.
#
# The existing unique indexes cannot catch that. `import_target` is one
# import link per MO record; the other is one link per (target, site,
# external_id). Two imports make two MO records, so they collide on
# neither.
#
# Same shape as `import_target` beside it: a stored generated column
# that is NULL for everything but an import link, plus a unique index.
# MySQL has no partial index; InnoDB treats the NULLs as
# non-conflicting. `target_type` is part of the value because an
# observation id and a photo id are numbers from different namespaces
# and would otherwise collide.
#
# Images need the repair below first; observations are clean already
# (0 of 78,564 in production).
class OneImportLinkPerRemoteRecord < ActiveRecord::Migration[7.2]
  IMPORT_SOURCE =
    "(CASE WHEN relationship = 1 " \
    "THEN CONCAT(external_site_id, ':', target_type, ':', external_id) END)"

  REPAIR = "bin/rails runner script/merge_duplicate_inat_images.rb --apply"

  # A copy of the table as this migration needs it, rather than the
  # application's model -- that one goes on changing after this
  # migration is written.
  class MigrationExternalLink < ActiveRecord::Base
    self.table_name = "external_links"
  end

  def up
    refuse_until_repaired
    change_table(:external_links, bulk: true) do |t|
      t.virtual(:import_source, type: :string, stored: true, as: IMPORT_SOURCE)
      t.index(:import_source, unique: true,
                              name: "index_external_links_on_import_source")
    end
  end

  def down
    remove_column(:external_links, :import_source)
  end

  private

  # The index cannot go on while two MO records claim one remote
  # record, so say which repair clears it rather than failing on a
  # duplicate-key error.
  def refuse_until_repaired
    duplicates = MigrationExternalLink.where(relationship: 1).
                 group(:external_site_id, :target_type, :external_id).
                 having(Arel.star.count.gt(1)).count
    return if duplicates.empty?

    raise(<<~MESSAGE)
      #{duplicates.size} remote records are claimed by more than one MO
      record, so the unique index cannot be added yet.

      Run the repair first, reading its dry run before applying it:
        #{REPAIR.sub(" --apply", "")}
        #{REPAIR}
    MESSAGE
  end
end

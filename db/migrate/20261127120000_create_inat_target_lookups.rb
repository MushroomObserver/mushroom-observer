# frozen_string_literal: true

# Which iNat taxon or place a project's target Name or Location resolves
# to. These answers lived in Solid Cache under a 30-day TTL, which
# invalidated on the MO record changing and not on iNaturalist changing
# the taxon. A committed taxon swap deactivates the id MO saved, so the
# alert poll asks for an inactive taxon and hears nothing, and the only
# thing that catches it is asking again. `checked_at` makes that a
# bounded daily re-confirmation instead of a matter of which cache entry
# expires when, and it is also how far back a refresh scans when an id
# turns out to have moved.
#
# A row per target rather than per project, since the answer is the same
# wherever a Name is targeted. The row's existence is what separates the
# three states a reader needs: no row means the target has not been
# looked up, which is what the pages and the import read to say how much
# of a project they can speak for, while a row with no `inat_id` means
# iNaturalist answered and knew nothing. A miss is worth a row -- it
# costs a lookup to establish.
class CreateInatTargetLookups < ActiveRecord::Migration[7.2]
  def change
    create_table(:inat_target_lookups) do |t|
      t.string(:target_type, limit: 30, null: false)
      t.integer(:target_id, null: false)
      t.integer(:inat_id)
      t.integer(:matching_version, null: false)
      t.datetime(:target_updated_at, null: false)
      t.datetime(:checked_at, null: false)
      t.timestamps
    end

    add_index(:inat_target_lookups, [:target_type, :target_id],
              unique: true, name: "index_inat_target_lookups_on_target")
    add_index(:inat_target_lookups, :checked_at)
  end
end

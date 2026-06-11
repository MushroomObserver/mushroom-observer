# frozen_string_literal: true

# Index users.inat_username and users.name so collector resolution does
# point lookups instead of full table scans.
#
# Observation.resolve_collector (#4211 / PR #4452) looks a collector string
# up against User#inat_username and User#name on every resolved row — on the
# live edit and iNat-import paths, and in bulk in the MigrateCollectorNotes
# seeding pass. Only `login` was indexed, so each non-login lookup scanned
# the whole users table; the seeding pass's tens of thousands of rows turned
# that into a 25-minute run (free-text/no-match values scan the entire table
# fruitlessly). These two indexes make each lookup O(log n).
#
# Deploy this on its own, ahead of and separate from the MigrateCollectorNotes
# seeding migration (PR #4452). Building these two indexes is quick (the users
# table is small), so its maintenance window is negligible; once the indexes
# exist, the seeding migration's much longer offline window shrinks
# accordingly. The seeding migration is dated later than this one so it runs
# second and benefits from these indexes.
class AddIndexesForCollectorUserLookups < ActiveRecord::Migration[7.2]
  def change
    change_table(:users, bulk: true) do |t|
      t.index(:inat_username, name: "index_users_on_inat_username")
      t.index(:name, name: "index_users_on_name")
    end
  end
end

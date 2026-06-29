# frozen_string_literal: true

# Drop the dead `skip_inat_update` boolean from inat_imports. It was added
# 2026-06-12 but never wired into any code path; skipping the iNat write-back
# is handled entirely by the `writeback` enum (added 2026-06-16). Guarded by
# column_exists? so it is a no-op on databases where the column was already
# removed by hand — one of the sources of db/schema.rb churn.
class RemoveSkipInatUpdateFromInatImports < ActiveRecord::Migration[7.2]
  def up
    return unless column_exists?(:inat_imports, :skip_inat_update)

    remove_column(:inat_imports, :skip_inat_update)
  end

  def down
    return if column_exists?(:inat_imports, :skip_inat_update)

    add_column(:inat_imports, :skip_inat_update, :boolean,
               default: false, null: false)
  end
end

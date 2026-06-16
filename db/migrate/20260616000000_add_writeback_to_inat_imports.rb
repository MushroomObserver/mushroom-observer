# frozen_string_literal: true

# Per-import policy for stamping the MO link back onto the source iNat
# observation. Backed by the InatImport#writeback enum:
#   default (0) - no admin choice; importer uses the environment default
#                 (skip in development, write back in production)
#   skip    (1) - admin forced the write-back off
#   force   (2) - admin forced the write-back on (even in development)
class AddWritebackToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column(:inat_imports, :writeback, :integer, default: 0, null: false)
  end
end

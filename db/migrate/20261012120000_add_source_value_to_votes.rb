# frozen_string_literal: true

# #5480: the value an import or resync last wrote to a vote.
#
# A reflection's importer is its owner, so the vote the iNat engine
# manages and the vote the observer casts by hand are one row. Telling
# them apart used to rest on `external_site_id`, which also records
# where the row came from -- one column carrying both a fact that never
# changes and a claim that has to. Holding the engine's value instead
# makes the question a comparison: the row is the engine's while its
# value is the one the engine wrote, and a person changing it needs no
# bookkeeping to say so.
#
# Nullable, and null means the engine has no write on record and leaves
# the row alone. Existing rows start there; the #5480 repair fills in
# the ones whose value the import accounts for.
class AddSourceValueToVotes < ActiveRecord::Migration[7.2]
  def change
    add_column(:votes, :source_value, :float)
  end
end

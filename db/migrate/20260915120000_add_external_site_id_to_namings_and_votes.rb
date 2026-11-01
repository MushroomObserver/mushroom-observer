# frozen_string_literal: true

# #4215: provenance marker for source-derived namings and votes. The
# iNat importer stamps the rows it creates on a reflection, and the
# resync's taxon engine moves only stamped rows, so a person's namings
# and votes on a reflection are never touched by a sync. Nullable: a
# native naming or vote has no site. Existing reflections are stamped by
# script/backfill_naming_provenance.rb.
class AddExternalSiteIDToNamingsAndVotes < ActiveRecord::Migration[7.2]
  def change
    add_column(:namings, :external_site_id, :integer)
    add_index(:namings, :external_site_id)
    add_column(:votes, :external_site_id, :integer)
    add_index(:votes, :external_site_id)
  end
end

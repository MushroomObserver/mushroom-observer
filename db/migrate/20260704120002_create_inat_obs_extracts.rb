# frozen_string_literal: true

# Compact per-observation cache of the comparison-relevant fields of an iNat
# observation, populated by script/build_inat_obs_extracts.rb from batched
# public API fetches (#4585). Deliberately not the full iNat JSON: the
# reflection comparator and discovery matching need only these fields, and
# the importer's notes snapshot already serves display needs.
#
# lat/lng are iNat's public coordinates — blurred when `obscured` is true,
# so comparisons must allow for `public_accuracy` (meters) in that case.
# `photos` is a JSON array of { "id" =>, "url" => } hashes (medium-size
# URLs); photo perceptual hashes live in inat_photo_hashes, keyed by photo
# id, so they survive extract refetches.
class CreateInatObsExtracts < ActiveRecord::Migration[7.2]
  def change
    create_table(:inat_obs_extracts) do |table|
      identity_columns(table)
      comparison_columns(table)
      table.datetime(:inat_updated_at)
      table.datetime(:fetched_at, null: false)
      table.timestamps
      table.index(:inat_id, unique: true)
      table.index(:inat_login)
    end
  end

  private

  def identity_columns(table)
    table.bigint(:inat_id, null: false)
    table.string(:inat_login)
  end

  def comparison_columns(table)
    table.date(:observed_on)
    table.decimal(:lat, precision: 15, scale: 10)
    table.decimal(:lng, precision: 15, scale: 10)
    table.float(:public_accuracy)
    table.boolean(:obscured, null: false, default: false)
    table.string(:taxon_name)
    table.string(:taxon_rank)
    table.string(:place_guess, limit: 1024)
    table.text(:description)
    table.json(:photos)
    table.json(:ofvs)
  end
end

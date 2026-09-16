# frozen_string_literal: true

# #5244: ~7 Locations were created via console access with a nil
# scientific_name, bypassing Location's presence validations (only a
# DB constraint reaches that path). No `default:` backfill is passed
# deliberately -- if any row with a nil name/scientific_name exists
# when this runs, the migration should fail loudly rather than
# silently paper over bad data with a placeholder string.
class AddNotNullToLocationsNameAndScientificName < ActiveRecord::Migration[7.2]
  def change
    change_column_null(:locations, :name, false)
    change_column_null(:locations, :scientific_name, false)
  end
end

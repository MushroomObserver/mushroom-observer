# frozen_string_literal: true

# Cached flag: true when `Observation#lat` / `lng` is geographically
# far (>50 km) from its `location`'s bounding box. GPS-based search
# scopes (`gps_in_box`, `gps_in_box_over_dateline`) exclude dubious
# rows so obs whose GPS contradicts an explicit label don't leak into
# location-filtered results (issue #4159).
#
# The column is populated by `Observation#set_gps_dubious` on save and
# backfilled once by `script/backfill_gps_dubious.rb`.
class AddGpsDubiousToObservations < ActiveRecord::Migration[7.2]
  def change
    add_column(:observations, :gps_dubious,
               :boolean, default: false, null: false)
  end
end

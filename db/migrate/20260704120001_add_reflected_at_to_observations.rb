# frozen_string_literal: true

# When the reflection-resolution engine (#4585) brought this observation to
# — or verified it as — a clean reflection of its imported source (equal to
# what a fresh import would produce). Set once by the resolution engine;
# never cleared in normal operation (#4214 read-only enforcement prevents
# MO-side divergence). NULL means not (yet) a verified reflection.
class AddReflectedAtToObservations < ActiveRecord::Migration[7.2]
  def change
    change_table(:observations, bulk: true) do |t|
      t.datetime(:reflected_at)
      t.index(:reflected_at)
    end
  end
end

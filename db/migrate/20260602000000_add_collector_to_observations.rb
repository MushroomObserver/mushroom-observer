# frozen_string_literal: true

# Adds a Collector identity to observations, separate from the user who
# entered the record. `collector` holds the display string (the iNat
# collector field for imports, the creator's name for native obs).
# `collector_user_id` is the optional FK to the MO user who collected
# the specimen, when that identity is known. See #4211.
class AddCollectorToObservations < ActiveRecord::Migration[7.2]
  def change
    add_column(:observations, :collector, :string, limit: 1024)
    # users.id is legacy `int`, so the FK column must match (not bigint).
    add_reference(
      :observations, :collector_user,
      type: :integer, null: true, foreign_key: { to_table: :users }
    )
  end
end

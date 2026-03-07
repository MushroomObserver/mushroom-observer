# frozen_string_literal: true

# Reverse the FieldSlip-Observation relationship from
# field_slips.observation_id to observations.field_slip_id.
# This enables one FieldSlip to have many Observations (needed for
# the Occurrences feature).
class ReverseFieldSlipObservationRelationship < ActiveRecord::Migration[7.2]
  def up
    add_column(:observations, :field_slip_id, :integer)
    add_index(:observations, :field_slip_id)

    # Migrate existing data
    execute(<<~SQL.squish)
      UPDATE observations
      INNER JOIN field_slips ON field_slips.observation_id = observations.id
      SET observations.field_slip_id = field_slips.id
    SQL

    remove_column(:field_slips, :observation_id)
  end

  def down
    add_column(:field_slips, :observation_id, :integer)

    execute(<<~SQL.squish)
      UPDATE field_slips
      INNER JOIN observations ON observations.field_slip_id = field_slips.id
      SET field_slips.observation_id = observations.id
    SQL

    remove_index(:observations, :field_slip_id)
    remove_column(:observations, :field_slip_id)
  end
end

# frozen_string_literal: true

# Move field_slip_id from observations to occurrences.
# For each observation with a field_slip_id:
#   - If it already has an occurrence, set that occurrence's field_slip_id
#   - If not, create a single-observation occurrence and set field_slip_id
class MoveFieldSlipFromObservationsToOccurrences < ActiveRecord::Migration[7.2]
  def up
    add_column(:occurrences, :field_slip_id, :integer)
    add_index(:occurrences, :field_slip_id)

    migrate_field_slip_data

    remove_column(:observations, :field_slip_id)
  end

  def down
    add_column(:observations, :field_slip_id, :integer)
    add_index(:observations, :field_slip_id,
              name: "index_observations_on_field_slip_id")

    # Reverse: copy field_slip_id from occurrence back to observations
    execute(<<~SQL.squish)
      UPDATE observations
      INNER JOIN occurrences
        ON observations.occurrence_id = occurrences.id
      SET observations.field_slip_id = occurrences.field_slip_id
      WHERE occurrences.field_slip_id IS NOT NULL
    SQL

    remove_column(:occurrences, :field_slip_id)
  end

  private

  def migrate_field_slip_data
    # First: observations that already have an occurrence
    execute(<<~SQL.squish)
      UPDATE occurrences
      INNER JOIN observations
        ON observations.occurrence_id = occurrences.id
      SET occurrences.field_slip_id = observations.field_slip_id
      WHERE observations.field_slip_id IS NOT NULL
        AND occurrences.field_slip_id IS NULL
    SQL

    # Second: observations with field_slip but no occurrence
    # Create a single-observation occurrence for each
    create_solo_occurrences
  end

  def create_solo_occurrences
    rows = execute(<<~SQL.squish)
      SELECT id, user_id, field_slip_id
      FROM observations
      WHERE field_slip_id IS NOT NULL
        AND occurrence_id IS NULL
    SQL

    rows.each do |obs_id, user_id, field_slip_id|
      execute(<<~SQL.squish)
        INSERT INTO occurrences
          (user_id, primary_observation_id, field_slip_id,
           has_specimen, created_at, updated_at)
        VALUES
          (#{user_id}, #{obs_id}, #{field_slip_id},
           0, NOW(), NOW())
      SQL
      occ_id = execute("SELECT LAST_INSERT_ID()").first[0]
      execute(<<~SQL.squish)
        UPDATE observations
        SET occurrence_id = #{occ_id}
        WHERE id = #{obs_id}
      SQL
    end
  end
end

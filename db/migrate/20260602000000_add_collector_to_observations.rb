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

    # ALTER TABLE rebuilds the ~1.8M-row observations table, which resets its
    # InnoDB index statistics. Re-analyzing observations ALONE leaves it
    # inconsistent with its hot join partners (project_observations, names):
    # the optimizer then full-scans observations for the project list-search
    # join (SELECT DISTINCT names ... JOIN project_observations) instead of
    # driving from the handful of project_observations rows — turning a ~10ms
    # query into 140s (measured on a prod copy). Refresh all three together so
    # their stats stay mutually consistent and the join order stays correct.
    # (The deploy runs migrations but no separate post-migrate step, so this
    # belongs here; #4211.)
    reversible do |dir|
      dir.up do
        execute("ANALYZE TABLE observations")
        execute("ANALYZE TABLE project_observations")
        execute("ANALYZE TABLE names")
      end
    end
  end
end

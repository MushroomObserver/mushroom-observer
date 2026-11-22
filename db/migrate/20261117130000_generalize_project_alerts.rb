# frozen_string_literal: true

# One ledger for both sources (#5721). A project hears about a matching
# observation whether iNaturalist identified it or somebody entered it
# here, and what it has been told about is one question, so the rows
# live in one table rather than two.
#
# What an iNat row carries stays as it was, with the columns relaxed to
# allow what an MO row has instead: no external site, no remote ids, an
# observation of ours, and the record whose arrival said so -- an
# Observation, a Naming or a Comment.
class GeneralizeProjectAlerts < ActiveRecord::Migration[7.2]
  TARGET_INDEX = "index_project_alerts_on_project_and_target"
  OBSERVATION_INDEX = "index_project_alerts_on_project_and_observation"

  def up
    rename_table(:project_external_site_alerts, :project_alerts)
    change_table(:project_alerts, bulk: true) do |t|
      t.change_null(:external_site_id, true)
      t.change_null(:remote_identification_id, true)
      t.change_null(:remote_observation_id, true)
      t.integer(:observation_id)
      t.string(:target_type, limit: 20)
      t.integer(:target_id)
      t.index([:project_id, :target_type, :target_id],
              name: TARGET_INDEX, unique: true)
      t.index([:project_id, :observation_id], name: OBSERVATION_INDEX)
    end
  end

  def down
    change_table(:project_alerts, bulk: true) do |t|
      t.remove_index(name: TARGET_INDEX)
      t.remove_index(name: OBSERVATION_INDEX)
      t.remove(:observation_id, :target_type, :target_id)
      t.change_null(:external_site_id, false)
      t.change_null(:remote_identification_id, false)
      t.change_null(:remote_observation_id, false)
    end
    rename_table(:project_alerts, :project_external_site_alerts)
  end
end

# frozen_string_literal: true

# Which of two messages an alert belongs in, and the watched name it
# matched (#5677).
#
# `kind` splits the single digest into a new-observation message and an
# other-activity one: a confirming identification on an observation the
# project has already been told about is activity, not a find. The
# index is what answers that question per row.
#
# `target_name` is the name the project watches, which is what the
# subject line names. It differs from `name` once a watched genus
# alerts on its species.
#
# Existing rows predate descendant matching, which matched only an
# identification of a target taxon itself -- so for them the identified
# name is the watched name.
class AddKindAndTargetNameToProjectSiteAlerts < ActiveRecord::Migration[7.2]
  # Copy of the table as this migration needs it, rather than the
  # application's model -- that goes on changing after this migration
  # is written.
  class MigrationProjectExternalSiteAlert < ActiveRecord::Base
    self.table_name = "project_external_site_alerts"
  end

  OBSERVATION_INDEX = "index_project_site_alerts_on_project_site_and_obs"

  def up
    change_table(:project_external_site_alerts, bulk: true) do |t|
      t.string(:kind, limit: 20, null: false, default: "new_observation")
      t.string(:target_name)
      t.index([:project_id, :external_site_id, :remote_observation_id],
              name: OBSERVATION_INDEX)
    end
    backfill_rows
  end

  def down
    change_table(:project_external_site_alerts, bulk: true) do |t|
      t.remove(:kind, :target_name)
      t.remove_index(name: OBSERVATION_INDEX)
    end
  end

  private

  # A row at a time: the table holds a few weeks of a low-volume
  # feature, so nothing here needs batching.
  def backfill_rows
    MigrationProjectExternalSiteAlert.order(:alerted_at, :id).
      group_by { |alert| observation_key(alert) }.
      each_value { |alerts| backfill_group(alerts) }
  end

  # Only the first row for an observation announced it; the rest were
  # the later identifications on one the project had already heard
  # about.
  def backfill_group(alerts)
    alerts.each_with_index do |alert, index|
      alert.update_columns(
        target_name: alert.target_name || alert.name,
        kind: index.zero? ? "new_observation" : "other_activity"
      )
    end
  end

  def observation_key(alert)
    [alert.project_id, alert.external_site_id, alert.remote_observation_id]
  end
end

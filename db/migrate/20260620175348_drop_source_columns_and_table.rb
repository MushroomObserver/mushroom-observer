# frozen_string_literal: true

# Phase 2 of consolidating Source into the ExternalLink relationship model
# (#4299). Drops the now-superseded Source table and the
# observations/images source columns. MUST run only AFTER the phase-1 deploy
# (#4568) and AFTER script/backfill_external_links_from_sources.rb has been
# run in production — the backfill reads these columns to build the import
# ExternalLinks, so dropping them first would lose the data.
#
# Order matters in MySQL: drop the FK before the index that backs it, and
# the index before its columns.
class DropSourceColumnsAndTable < ActiveRecord::Migration[7.2]
  def up
    remove_foreign_key(:observations, :sources)
    change_table(:observations, bulk: true) do |t|
      t.remove_index(name: "index_observations_on_source_id_and_external_id")
      t.remove(:source_id, :external_id, :last_synced_at)
    end
    change_table(:images, bulk: true) do |t|
      t.remove_index(name: "index_images_on_source_id_and_external_id")
      t.remove(:source_id, :external_id)
    end
    drop_table(:sources)
  end

  def down
    recreate_sources_table
    restore_observation_columns
    restore_image_columns
  end

  private

  def recreate_sources_table
    create_table(:sources, id: :integer) do |t|
      t.string(:name, limit: 100, null: false)
      t.string(:url, limit: 1024)
      t.text(:description)
      t.datetime(:last_successful_sync_at)
      t.timestamps
      t.index(:name, unique: true, name: "index_sources_on_name")
    end
  end

  def restore_observation_columns
    obs_index = "index_observations_on_source_id_and_external_id"
    change_table(:observations, bulk: true) do |t|
      t.bigint(:source_id)
      t.string(:external_id, limit: 64)
      t.datetime(:last_synced_at)
      t.index([:source_id, :external_id], unique: true, name: obs_index)
    end
    add_foreign_key(:observations, :sources)
  end

  def restore_image_columns
    change_table(:images, bulk: true) do |t|
      t.bigint(:source_id)
      t.string(:external_id, limit: 64)
      t.index([:source_id, :external_id],
              name: "index_images_on_source_id_and_external_id")
    end
  end
end

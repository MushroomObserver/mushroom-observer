# frozen_string_literal: true

# First step of #4209 (foundation for #4208 — handling imported
# observations from iNat, MyCoPortal, and future external sources).
#
# Creates the `sources` table and seeds the iNaturalist row. The
# table replaces the iNat-specific `inat_id` column with a generic
# `(source_id, external_id)` pair on observations (added in the
# follow-on migration). `last_successful_sync_at` is read by the
# sync job (#4215) to decide which observations to refresh.
class CreateSources < ActiveRecord::Migration[7.2]
  def up
    create_table(:sources) do |t|
      t.string(:name, null: false, limit: 100)
      t.string(:url, limit: 1024)
      t.text(:description)
      t.datetime(:last_successful_sync_at)
      t.timestamps
      t.index(:name, unique: true)
    end

    execute(<<~SQL.squish)
      INSERT INTO sources (name, url, description, created_at, updated_at)
      VALUES ('iNaturalist',
              'https://www.inaturalist.org',
              'Observations imported from iNaturalist via the iNat API.',
              NOW(), NOW())
    SQL
  end

  def down
    drop_table(:sources)
  end
end

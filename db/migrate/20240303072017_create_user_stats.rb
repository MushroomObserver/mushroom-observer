class CreateUserStats < ActiveRecord::Migration[7.1]
  def up
    create_table :user_stats do |t|
      t.integer(:user_id, default: 0, null: false)

      t.integer(:comments, default: 0, null: false)
      t.integer(:images, default: 0, null: false)
      t.integer(:location_description_authors, default: 0, null: false)
      t.integer(:location_description_editors, default: 0, null: false)
      t.integer(:locations, default: 0, null: false)
      t.integer(:location_versions, default: 0, null: false)
      t.integer(:name_description_authors, default: 0, null: false)
      t.integer(:name_description_editors, default: 0, null: false)
      t.integer(:names, default: 0, null: false)
      t.integer(:name_versions, default: 0, null: false)
      t.integer(:namings, default: 0, null: false)
      t.integer(:observations, default: 0, null: false)
      t.integer(:sequences, default: 0, null: false)
      t.integer(:sequenced_observations, default: 0, null: false)
      t.integer(:species_list_entries, default: 0, null: false)
      t.integer(:species_lists, default: 0, null: false)
      t.integer(:translation_strings, default: 0, null: false)
      t.integer(:votes, default: 0, null: false)

      t.string(:languages)
      t.string(:bonuses)

      t.timestamps(default: Time.zone.now)
    end
    add_index(:user_stats, :user_id, name: :user_index)
  end

  def down
    drop_table :user_stats
  end
end

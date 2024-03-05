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
      t.integer(:translation_string_versions, default: 0, null: false)
      t.integer(:votes, default: 0, null: false)

      # t.integer(:ar, default: 0, null: false)
      # t.integer(:be, default: 0, null: false)
      # t.integer(:de, default: 0, null: false)
      # t.integer(:el, default: 0, null: false)
      # t.integer(:es, default: 0, null: false)
      # t.integer(:fa, default: 0, null: false)
      # t.integer(:fr, default: 0, null: false)
      # t.integer(:it, default: 0, null: false)
      # t.integer(:jp, default: 0, null: false)
      # t.integer(:pl, default: 0, null: false)
      # t.integer(:pt, default: 0, null: false)
      # t.integer(:ru, default: 0, null: false)
      # t.integer(:tr, default: 0, null: false)
      # t.integer(:uk, default: 0, null: false)
      # t.integer(:zh, default: 0, null: false)

      t.timestamps
    end
    add_index(:user_stats, :user_id, name: :user_index)
  end

  def down
    drop_table :user_stats
  end
end

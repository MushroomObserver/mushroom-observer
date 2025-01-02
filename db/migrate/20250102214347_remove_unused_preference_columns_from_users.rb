class RemoveUnusedPreferenceColumnsFromUsers < ActiveRecord::Migration[7.1]
  def change
    remove_column :users, :thumbnail_size, :integer
    remove_column :users, :hide_authors, :integer
  end
end

class IncreaseNameAuthorLimit < ActiveRecord::Migration
  # define up & down because change method doesn't support change_column
  def up
    # These numbers explained in name.rb, Limits section
    change_column :names,          :author,       :string, limit: 134
    change_column :names,          :display_name, :string, limit: 238
    change_column :names,          :search_name,  :string, limit: 255
    change_column :names,          :sort_name,    :string, limit: 285

    change_column :names_versions, :author,       :string, limit: 134
    change_column :names_versions, :display_name, :string, limit: 238
    change_column :names_versions, :search_name,  :string, limit: 255
    change_column :names_versions, :sort_name,    :string, limit: 275
  end

  def down
    change_column :names, :author,                :string, limit: 100
    change_column :names, :display_name,          :string, limit: 200
    change_column :names, :search_name,           :string, limit: 200
    change_column :names, :sort_name,             :string, limit: 200

    change_column :names_versions, :author,       :string, limit: 100
    change_column :names_versions, :display_name, :string, limit: 200
    change_column :names_versions, :search_name,  :string, limit: 200
    change_column :names_versions, :sort_name,    :string, limit: 200
  end
end

class AdjustNameLimits < ActiveRecord::Migration[4.2]
  # define up & down because change method doesn't support change_column
  def up
    # These numbers explained in name.rb, Limits section
    change_column :names,          :display_name, :string, limit: 204
    change_column :names,          :search_name,  :string, limit: 221
    change_column :names,          :sort_name,    :string, limit: 241

    change_column :names_versions, :display_name, :string, limit: 204
    change_column :names_versions, :search_name,  :string, limit: 221
    change_column :names_versions, :sort_name,    :string, limit: 241
  end

  def down
    change_column :names,          :display_name, :string, limit: 200
    change_column :names,          :search_name,  :string, limit: 200
    change_column :names,          :sort_name,    :string, limit: 200

    change_column :names_versions, :display_name, :string, limit: 200
    change_column :names_versions, :search_name,  :string, limit: 200
    change_column :names_versions, :sort_name,    :string, limit: 200
  end
end

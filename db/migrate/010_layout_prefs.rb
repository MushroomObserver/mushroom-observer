class LayoutPrefs < ActiveRecord::Migration
  def self.up
    add_column :users,  "rows", :integer
    add_column :users,  "columns", :integer
    add_column :users,  "alternate_rows", :boolean, :default => true, :null => false
    add_column :users,  "alternate_columns", :boolean, :default => true, :null => false
    add_column :users,  "vertical_layout", :boolean, :default => true, :null => false
    for u in User.find(:all)
      u.rows = 5
      u.columns = 3
      u.save
    end
  end

  def self.down
    remove_column :users,  "rows"
    remove_column :users,  "columns"
    remove_column :users,  "alternate_rows"
    remove_column :users,  "alternate_columns"
    remove_column :users,  "vertical_layout"
  end
end

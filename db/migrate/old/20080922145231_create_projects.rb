class CreateProjects < ActiveRecord::Migration
  def self.up
    create_table :projects do |t|
      t.integer(:user_id, :null => false)
      t.integer(:admin_group_id, :null => false)
      t.integer(:user_group_id, :null => false)
      t.string(:title, :limit => 100, :null => false)
      t.text(:summary)
      t.timestamps
    end
  end

  def self.down
    drop_table(:projects)
  end
end

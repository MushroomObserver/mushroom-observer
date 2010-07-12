class CreateUserGroups < ActiveRecord::Migration
  def self.up
    create_table :user_groups do |t|
      t.string :name, :null => false
      t.timestamps
    end
    
    create_table(:user_groups_users, :id => false) do |t|
      t.integer :user_id, :null => false
      t.integer :user_group_id, :null => false
    end
    
    group = UserGroup.new()
    group.name = 'reviewers'
    group.save()
    for login in ['admin', 'nathan', 'darv', 'pellaea', 'mykoweb', 'TomVolk']
      user = User.find_by_login(login)
      user.user_groups << group
      user.save
    end
  end

  def self.down
    drop_table :user_groups
    drop_table :user_groups_users
  end
end

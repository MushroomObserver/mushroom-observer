class MoreNotifications < ActiveRecord::Migration
  def self.up
    create_table "interests", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.column "object_type", :string, :limit => 30
      t.column "object_id",   :integer
      t.column "user_id",     :integer
      t.column "state",       :boolean
    end

    add_column :users, "comment_response_email", :boolean, :default => true, :null => false
    add_column :users, "name_proposal_email",    :boolean, :default => true, :null => false
    add_column :users, "consensus_change_email", :boolean, :default => true, :null => false
    add_column :users, "name_change_email",      :boolean, :default => true, :null => false

    User.connection.update("update users set
        comment_response_email = comment_email,
        name_proposal_email    = comment_email,
        consensus_change_email = comment_email,
        name_change_email      = comment_email")
  end

  def self.down
    drop_table "interests"

    remove_column :users, "comment_response_email"
    remove_column :users, "name_proposal_email"
    remove_column :users, "consensus_change_email"
    remove_column :users, "name_change_email"
  end
end

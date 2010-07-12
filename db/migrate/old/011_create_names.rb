class CreateNames < ActiveRecord::Migration
  def self.up
    create_table :names, :force => true do |t|
      t.column :created, :datetime
      t.column :modified, :datetime
      t.column :user_id, :integer, :default => 0, :null => false
      t.column :version, :integer, :default => 0, :null => false
      t.column :rank, :enum, :limit => Name.all_ranks
      t.column :text_name, :string, :limit => 100
      t.column :author, :string, :limit => 100
      t.column :display_name, :string, :limit => 200
      t.column :observation_name, :string, :limit => 200
      t.column :search_name, :string, :limit => 200
      t.column :notes, :text
    end
    create_table :past_names, :force => true do |t|
      t.column :name_id, :integer
      t.column :created, :datetime
      t.column :modified, :datetime
      t.column :user_id, :integer, :default => 0, :null => false
      t.column :version, :integer, :default => 0, :null => false
      t.column :rank, :enum, :limit => Name.all_ranks
      t.column :text_name, :string, :limit => 100
      t.column :author, :string, :limit => 100
      t.column :display_name, :string, :limit => 200
      t.column :observation_name, :string, :limit => 200
      t.column :search_name, :string, :limit => 200
      t.column :notes, :text
    end
    add_column :observations, "name_id", :integer
    
    # Name.names_from_string "Amanita baccata senu Arora"
    user = User.find(1)
    fungi = Name.make_name :Kingdom, 'Fungi', :display_name => 'Kingdom of __Fungi__', :observation_name => '__Fungi sp.__', :search_name => 'Fungi sp.'
    fungi.user = user
    fungi.save
    obs = Observation.find :all
    for o in obs
      names = Name.names_from_string o.what.squeeze(' ')
      if names.last.nil?
        print sprintf("Unable to create Name for %s\n", o.what)
      else
        for n in names
          n.user = user
          n.save
        end
        o.name = names.last
        o.save
        near = o.what.index(' near ') or o.what.index(' cf. ')
      end
    end
  end
  
  def self.down
    drop_table :names
    drop_table :past_names
    remove_column :observations, "name_id"
  end
end

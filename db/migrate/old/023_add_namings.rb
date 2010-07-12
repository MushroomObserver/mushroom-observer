class AddNamings < ActiveRecord::Migration
  def self.up
    create_table "namings", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.column "created",           :datetime
      t.column "modified",          :datetime
      t.column "observation_id",    :integer
      t.column "name_id",           :integer
      t.column "user_id",           :integer
    end

    create_table "naming_reasons", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.column "naming_id",         :integer
      t.column "reason",            :integer
      t.column "notes",             :text
    end

    create_table "votes", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :force => true do |t|
      t.column "created",       :datetime
      t.column "modified",      :datetime
      t.column "naming_id",     :integer
      t.column "user_id",       :integer
      t.column "value",         :integer
    end

    for o in Observation.find(:all)
      # Create rudimentary naming for each pre-existing observation.
      naming = Naming.new(
        :created        => o.created,
        :modified       => o.modified,
        :observation_id => o.id,
        :name_id        => o.name_id,
        :user_id        => o.user_id
      )
      naming.save
    end
  end

  def self.down
    drop_table "namings"
    drop_table "naming_reasons"
    drop_table "votes"
  end
end

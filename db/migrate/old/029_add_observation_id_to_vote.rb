class AddObservationIdToVote < ActiveRecord::Migration
  def self.up
    add_column :votes, "observation_id", :integer, :default => 0
    
    Vote.connection.update %(
      UPDATE votes v, namings n
      SET v.observation_id = n.observation_id
      WHERE v.naming_id = n.id
    )
  end

  def self.down
    remove_column :votes, "observation_id"
  end
end

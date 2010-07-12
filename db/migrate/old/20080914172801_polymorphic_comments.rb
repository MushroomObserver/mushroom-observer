class PolymorphicComments < ActiveRecord::Migration
  def self.up
    add_column :comments, "object_type", :string, :limit => 30
    add_column :comments, "object_id", :integer
    Comment.connection.update %(
      UPDATE comments
      SET object_id = observation_id, object_type = 'Observation'
      WHERE id > 0
    )
    remove_column :comments, :observation_id
  end

  def self.down
    add_column :comments, "observation_id", :integer
    Comment.connection.update %(
      UPDATE comments
      SET observation_id = object_id
      WHERE id > 0
    )
    remove_column :comments, :object_type
    remove_column :comments, :object_id
  end
end

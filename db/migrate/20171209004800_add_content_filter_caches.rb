class AddContentFilterCaches < ActiveRecord::Migration
  def up
    add_column :observations, :lifeform, :string, limit: 1024
    add_column :observations, :text_name, :string, limit: 100
    add_column :observations, :classification, :text

    Name.connection.execute(%(
      UPDATE observations o, names n
      SET o.lifeform = n.lifeform,
          o.text_name = n.text_name,
          o.classification = n.classification
      WHERE o.name_id = n.id
    ))

    Name.connection.execute(%(
      UPDATE observations o, locations l
      SET o.where = l.name
      WHERE o.location_id = l.id
    ))
  end

  def down
    remove_column :observations, :lifeform
    remove_column :observations, :text_name
    remove_column :observations, :classification
  end
end

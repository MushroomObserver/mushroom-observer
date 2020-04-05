class CreateSpecimensAndHerbaria < ActiveRecord::Migration[4.2]
  def self.up
    create_table :specimens, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.integer :herbarium_id, null: false
      t.string :label, limit: 80, default: "", null: false
      t.date :when, null: false
      t.text :notes
      t.timestamps
    end

    create_table :observations_specimens, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", id: false, force: true do |t|
      t.integer :observation_id, default: 0, null: false
      t.integer :specimen_id, default: 0, null: false
    end

    create_table :herbaria, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.text :mailing_address
      t.integer :location_id
      t.string :email, limit: 80, default: "", null: false
      t.string :name, limit: 1024
      t.text :description
      t.timestamps
    end

    create_table :herbaria_curators, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", id: false, force: true do |t|
      t.integer :user_id, default: 0, null: false
      t.integer :herbarium_id, default: 0, null: false
    end
  end

  def self.down
    drop_table :herbaria_curators
    drop_table :herbaria
    drop_table :observations_specimens
    drop_table :specimens
  end
end

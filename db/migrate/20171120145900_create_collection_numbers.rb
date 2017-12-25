class CreateCollectionNumbers < ActiveRecord::Migration
  def up
    create_table :collection_numbers, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.timestamps
      t.integer  :user_id
      t.string   :name
      t.string   :number
    end

    create_table :collection_numbers_observations, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", id: false, force: true do |t|
      t.integer  :collection_number_id
      t.integer  :observation_id
    end
  end

  def down
    drop_table :collection_numbers
    drop_table :collection_numbers_observations
  end
end

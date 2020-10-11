class CreateObservationViews < ActiveRecord::Migration[5.2]
  def up
    create_table :observation_views, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.integer  :observation_id
      t.integer  :user_id
      t.datetime :last_view
    end
  end

  def down
    drop_table :observation_views
  end
end

class CreateObservationViews < ActiveRecord::Migration[5.2]
  def change
    create_table :observation_views, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.integer  :observation_id
      t.integer  :user_id
      t.datetime :last_view
    end
  end
end

class AddFilterObsImgedToUser < ActiveRecord::Migration
  def change
    add_column :users, :filter_obs_imged, :boolean, default: false, null: false
  end
end

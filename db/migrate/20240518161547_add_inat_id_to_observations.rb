class AddInatIdToObservations < ActiveRecord::Migration[7.1]
  def change
    add_column :observations, :inat_id, :integer
  end
end

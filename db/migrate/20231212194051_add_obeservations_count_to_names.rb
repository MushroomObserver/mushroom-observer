class AddObeservationsCountToNames < ActiveRecord::Migration[6.1]
  def change
    add_column :names, :observations_count, :integer
  end
end

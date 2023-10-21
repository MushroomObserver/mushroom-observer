class AddReviewedToObservationViews < ActiveRecord::Migration[6.1]
  def change
    add_column :observation_views, :reviewed, :boolean
  end
end

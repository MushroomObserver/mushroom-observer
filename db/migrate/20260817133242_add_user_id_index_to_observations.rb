# frozen_string_literal: true

class AddUserIDIndexToObservations < ActiveRecord::Migration[7.2]
  # `observations` had no index on `user_id` at all -- every "this
  # user's own/most recent observations" query (Observation.
  # recent_by_user, @user.observations, various by_user scopes) was a
  # full table scan. Composite with `created_at` so recent_by_user's
  # `ORDER BY created_at` is an index-order scan, not a filesort.
  def change
    add_index(:observations, [:user_id, :created_at])
  end
end

class UserStatsNoDefaultTimestamp < ActiveRecord::Migration[7.1]
  def change
    change_column_default(:user_stats, :created_at, nil)
    change_column_default(:user_stats, :updated_at, nil)
  end
end

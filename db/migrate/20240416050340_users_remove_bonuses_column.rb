class UsersRemoveBonusesColumn < ActiveRecord::Migration[7.1]
  def change
    remove_column :users, :bonuses
  end
end

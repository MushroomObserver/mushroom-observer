class AddUserIdToFieldSlips < ActiveRecord::Migration[7.1]
  def change
    add_column :field_slips, :user_id, :integer
  end
end

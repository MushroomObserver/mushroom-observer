class RemoveEmailCommentsAllFromUsers < ActiveRecord::Migration[7.2]
  def change
    remove_column :users, :email_comments_all, :boolean
  end
end

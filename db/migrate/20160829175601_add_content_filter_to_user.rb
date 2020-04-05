class AddContentFilterToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :content_filter, :string
  end
end

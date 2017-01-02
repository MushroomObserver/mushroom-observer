class AddContentFilterToUser < ActiveRecord::Migration
  def change
    add_column :users, :content_filter, :string
  end
end

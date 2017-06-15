class ChangeNamesAuthorLimit < ActiveRecord::Migration
  # define up & down because change method doesn't support change_column
  def up
    change_column :names, :author, :string, limit: 255
  end

  def down
    change_column :names, :author, :string, limit: 100
  end
end

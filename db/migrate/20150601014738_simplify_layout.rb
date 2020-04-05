class SimplifyLayout < ActiveRecord::Migration[4.2]
  def up
    add_column :users, :layout_count, :integer
    User.connection.update %(
      UPDATE users SET layout_count = rows*columns
    )
    # for u in User.all()
    #   u.layout_count = u.rows * u.columns
    #   u.save
    # end
    remove_column :users, :rows
    remove_column :users, :columns
    remove_column :users, :alternate_columns
    remove_column :users, :alternate_rows
    remove_column :users, :vertical_layout
  end

  def factors(value)
    for count in [3, 4, 5, 2, 7]
      return [value / count, count] if value % count == 0
    end
    [value, 1]
  end

  def down
    add_column :users, :vertical_layout, :boolean, default: true
    add_column :users, :alternate_rows, :boolean, default: true
    add_column :users, :alternate_columns, :boolean, default: true
    add_column :users, :columns, :integer
    add_column :users, :rows, :integer
    for u in User.all
      u.rows, u.columns = factors(u.layout_count)
      u.save
    end
    remove_column :users, :layout_count
  end
end

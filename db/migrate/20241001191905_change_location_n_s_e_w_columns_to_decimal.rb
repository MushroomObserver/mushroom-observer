class ChangeLocationNSEWColumnsToDecimal < ActiveRecord::Migration[7.1]
  def up
    change_column :locations, :north, :decimal, precision: 15, scale: 10,
                  null: false
    change_column :locations, :south, :decimal, precision: 15, scale: 10,
                  null: false
    change_column :locations, :east, :decimal, precision: 15, scale: 10,
                  null: false
    change_column :locations, :west, :decimal, precision: 15, scale: 10,
                  null: false
  end
  def down
    change_column :locations, :north, :float
    change_column :locations, :south, :float
    change_column :locations, :east, :float
    change_column :locations, :west, :float
  end
end

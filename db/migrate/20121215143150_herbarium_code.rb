class HerbariumCode < ActiveRecord::Migration[4.2]
  def self.up
    add_column(:herbaria, :code, :string, limit: 8, default: "", null: false)
  end

  def self.down
    remove_column :herbaria, :code
  end
end

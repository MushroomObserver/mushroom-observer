class UpdateSpecimensAndHerbaria < ActiveRecord::Migration[4.2]
  def self.up
    add_column(:specimens, :user_id, :integer, null: false)
    add_column(:specimens, :herbarium_label, :string, limit: 80, default: "", null: false)
    remove_column :specimens, :label
  end

  def self.down
    add_column(:specimens, :label, :string, limit: 80, default: "", null: false)
    remove_column :specimens, :herbarium_label
    remove_column :specimens, :user_id
  end
end

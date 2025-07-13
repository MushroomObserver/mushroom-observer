# frozen_string_literal: true

class AddUniqueIndexToHerbariaCode < ActiveRecord::Migration[7.2]
  def up
    change_column(:herbaria, :code, :string, limit: 8, null: true, default: nil)
    execute("UPDATE herbaria SET code = NULL WHERE code = ''")
    add_index(:herbaria, :code, unique: true, where: "code IS NOT NULL")
  end

  def down
    remove_index(:herbaria, :code)
    execute("UPDATE herbaria SET code = '' WHERE code is NULL")
    change_column(:herbaria, :code, :string, limit: 8, null: false)
  end
end

class AddNeedsNamingToObservations < ActiveRecord::Migration[7.1]
  def up
    add_column :observations, :needs_naming, :boolean, default: false,
                                                       null: false
    add_index :observations, :needs_naming, name: :needs_naming_index
  end

  def down
    remove_index :observations, :needs_naming, name: :needs_naming_index
    remove_column :observations, :needs_naming
  end
end

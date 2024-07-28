class RenameObservationsLongColumn < ActiveRecord::Migration[7.1]
  def change
    rename_column :observations, :long, :lng
  end
end

class RemoveHerbariumRecordWhen < ActiveRecord::Migration[4.2]
  def up
    remove_column :herbarium_records, :when
  end

  def down
    add_column :herbarium_records, :when, :date, null: false
  end
end

class AddPermalinkToQueryRecords < ActiveRecord::Migration[7.2]
  def change
    add_column :query_records, :permalink, :boolean, default: false
  end
end

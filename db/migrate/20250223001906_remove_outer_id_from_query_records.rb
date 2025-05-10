class RemoveOuterIdFromQueryRecords < ActiveRecord::Migration[7.2]
  def change
    remove_column(:query_records, :outer_id, :integer)
  end
end

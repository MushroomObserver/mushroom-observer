class AddIcnIdentifierToNames < ActiveRecord::Migration[5.2]
  def change
    add_column(:names, :icn_id, :integer)
    add_column(:names_versions, :icn_id, :integer)
  end
end

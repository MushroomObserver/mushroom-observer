class AddIcnIdentifierToNames < ActiveRecord::Migration[5.2]
  def change
    add_column(:names, :icn_identifier, :integer)
    add_column(:names_versions, :icn_identifier, :integer)
  end
end

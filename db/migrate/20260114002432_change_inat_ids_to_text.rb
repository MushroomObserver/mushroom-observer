class ChangeInatIdsToText < ActiveRecord::Migration[7.2]
  def up
    change_column(:inat_imports, :inat_ids, :text)
  end

  def down
    change_column(:inat_imports, :inat_ids, :string)
  end
end

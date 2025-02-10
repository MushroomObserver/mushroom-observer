class AddEndedToInatImport < ActiveRecord::Migration[7.2]
  def change
    add_column :inat_imports, :ended_at, :datetime
  end
end

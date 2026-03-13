class AddLastObsStartToInatImports < ActiveRecord::Migration[7.2]
  def change
    add_column :inat_imports, :last_obs_start, :datetime
  end
end

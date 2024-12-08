class CreateInatImports < ActiveRecord::Migration[7.1]
  def change
    create_table :inat_imports do |t|
      t.integer :user_id
      t.integer :state
      t.string :inat_ids

      t.timestamps
    end
  end
end

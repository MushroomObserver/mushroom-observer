class CreateLogoEntries < ActiveRecord::Migration[5.2]
  def change
    create_table :logo_entries do |t|

      t.timestamps
    end
  end
end

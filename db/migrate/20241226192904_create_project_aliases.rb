class CreateProjectAliases < ActiveRecord::Migration[7.1]
  def change
    create_table :project_aliases do |t|
      t.references :target, polymorphic: true
      t.string :name
      t.references :project, foreign_key: true

      t.timestamps
    end
  end
end

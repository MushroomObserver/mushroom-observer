class CreateSequences < ActiveRecord::Migration
  def change
    create_table :sequences do |t|
      t.integer :observation_id
      t.text :locus
      t.text :bases
      t.string :archive
      t.string :accession
      t.text :notes

      t.timestamps null: false
    end
  end
end

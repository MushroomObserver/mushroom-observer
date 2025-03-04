class AddSynonymIndexToNames < ActiveRecord::Migration[7.1]
  def up
    add_index :names, :synonym_id, name: :synonym_index
  end

  def down
    remove_index :names, :synonym_id, name: :synonym_index
  end
end

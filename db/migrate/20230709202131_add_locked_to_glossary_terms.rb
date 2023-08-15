class AddLockedToGlossaryTerms < ActiveRecord::Migration[6.1]
  def change
    add_column :glossary_terms, :locked, :boolean, default: false, null: false
  end
end

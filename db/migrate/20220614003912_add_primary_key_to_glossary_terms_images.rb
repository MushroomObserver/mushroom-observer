class AddPrimaryKeyToGlossaryTermsImages < ActiveRecord::Migration[6.1]
  def change
    rename_table("glossary_terms_images", "glossary_term_images")
    add_column(:glossary_term_images, :id, :primary_key)
  end
end

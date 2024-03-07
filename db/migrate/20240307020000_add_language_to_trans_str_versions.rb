class AddLanguageToTransStrVersions < ActiveRecord::Migration[7.1]
  def up
    add_column :translation_string_versions, :language_id, :integer
    TranslationString.connection.execute %(
      UPDATE translation_string_versions tsv
      JOIN translation_strings ts ON tsv.translation_string_id = ts.id
      SET tsv.language_id = ts.language_id
    )
  end

  def down
    remove_column :translation_string_versions, :language_id
  end
end

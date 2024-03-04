class RenameVersionTables < ActiveRecord::Migration[7.1]
  def change
    rename_table("glossary_terms_versions", "glossary_term_versions")
    rename_table("locations_versions", "location_versions")
    rename_table("location_descriptions_versions",
                 "location_description_versions")
    rename_table("names_versions", "name_versions")
    rename_table("name_descriptions_versions", "name_description_versions")
    rename_table("translation_strings_versions", "translation_string_versions")
  end
end

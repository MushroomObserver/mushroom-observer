class AddPrimaryKeyToDescriptionUserJoinTables < ActiveRecord::Migration[6.1]
  def change
    rename_table(
      "location_descriptions_admins", "location_description_admins"
    )
    add_column(:location_description_admins, :id, :primary_key)

    rename_table(
      "location_descriptions_authors", "location_description_authors"
    )
    add_column(:location_description_authors, :id, :primary_key)

    rename_table(
      "location_descriptions_editors", "location_description_editors"
    )
    add_column(:location_description_editors, :id, :primary_key)

    rename_table(
      "location_descriptions_readers", "location_description_readers"
    )
    add_column(:location_description_readers, :id, :primary_key)

    rename_table(
      "location_descriptions_writers", "location_description_writers"
    )
    add_column(:location_description_writers, :id, :primary_key)

    rename_table("name_descriptions_admins", "name_description_admins")
    add_column(:name_description_admins, :id, :primary_key)

    rename_table("name_descriptions_authors", "name_description_authors")
    add_column(:name_description_authors, :id, :primary_key)

    rename_table("name_descriptions_editors", "name_description_editors")
    add_column(:name_description_editors, :id, :primary_key)

    rename_table("name_descriptions_readers", "name_description_readers")
    add_column(:name_description_readers, :id, :primary_key)

    rename_table("name_descriptions_writers", "name_description_writers")
    add_column(:name_description_writers, :id, :primary_key)
  end
end

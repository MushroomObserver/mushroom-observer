class RenameSpecimenToHerbariumRecord < ActiveRecord::Migration

  TAG_PAIRS = [
    [ :SPECIMEN, :HERBARIUM_RECORD ],
    [ :specimen, :herbarium_record ],
    [ :SPECIMENS, :HERBARIUM_RECORDS ],
    [ :specimens, :herbarium_records ],
    [ :log_specimen_added, :log_herbarium_record_added ],
    [ :form_observations_specimen_available, :form_observations_specimen_available ],
    [ :form_observations_delete_specimens_help, :form_observations_delete_herbarium_records_help ],
    [ :show_observation_specimen_available, :show_observation_specimen_available ],
    [ :show_observation_specimen_not_available, :show_observation_specimen_not_available ],
    [ :show_observation_create_specimen, :show_observation_create_herbarium_record ],
    [ :herbarium_specimen_count, :herbarium_herbarium_record_count ],
    [ :show_herbarium_specimen_count, :show_herbarium_herbarium_record_count ],
    [ :add_specimen, :add_herbarium_record ],
    [ :add_specimen_title, :add_herbarium_record_title ],
    [ :add_specimen_add, :add_herbarium_record_add ],
    [ :add_specimen_herbarium_label, :add_herbarium_record_herbarium_label ],
    [ :add_specimen_herbarium_label_help, :add_herbarium_record_herbarium_label_help ],
    [ :add_specimen_notes, :add_herbarium_record_notes ],
    [ :add_specimen_cancel, :add_herbarium_record_cancel ],
    [ :add_specimen_already_exists, :add_herbarium_record_already_exists ],
    [ :add_specimen_not_a_curator, :add_herbarium_record_not_a_curator ],
    [ :specimen_herbarium, :herbarium_record_herbarium ],
    [ :specimen_herbarium_name, :herbarium_record_herbarium_name ],
    [ :specimen_herbarium_label, :herbarium_record_herbarium_label ],
    [ :specimen_herbarium_id, :herbarium_record_herbarium_id ],
    [ :specimen_user, :herbarium_record_user ],
    [ :specimen_when, :herbarium_record_when ],
    [ :specimen_notes, :herbarium_record_notes ],
    [ :specimen_created_at, :herbarium_record_created_at ],
    [ :specimen_updated_at, :herbarium_record_updated_at ],
    [ :show_specimen, :show_herbarium_record ],
    [ :edit_specimen, :edit_herbarium_record ],
    [ :edit_specimen_cannot_edit, :edit_herbarium_record_cannot_edit ],
    [ :edit_specimen_title, :edit_herbarium_record_title ],
    [ :edit_specimen_save, :edit_herbarium_record_save ],
    [ :specimen_index_title, :herbarium_record_index_title ],
    [ :herbarium_index_no_specimens, :herbarium_index_no_herbarium_records ],
    [ :herbarium_delete_specimen, :herbarium_delete_herbarium_record ],
    [ :herbarium_edit_specimen, :herbarium_edit_herbarium_record ],
    [ :observation_index_no_specimens, :observation_index_no_herbarium_records ],
    [ :list_specimens_title, :list_herbarium_records_title ],
    [ :delete_specimen_cannot_delete, :delete_herbarium_record_cannot_delete ],
    [ :email_subject_add_specimen_not_curator, :email_subject_add_herbarium_record_not_curator ],
    [ :email_add_specimen_not_curator_intro, :email_add_herbarium_record_not_curator_intro ]
  ]

  def up
    rename_column :observations_specimens, :specimen_id, :herbarium_record_id
    rename_table :observations_specimens, :herbarium_records_observations
    rename_table :specimens, :herbarium_records
    TAG_PAIRS.each do |from, to|
      rename_tag(from, to)
    end
  end

  def down
    rename_table :herbarium_records, :specimens
    rename_table :herbarium_records_observations, :observations_specimens
    rename_column :observations_specimens, :herbarium_record_id, :specimen_id
    TAG_PAIRS.each do |from, to|
      rename_tag(to, from)
    end
  end

  def rename_tag(from, to)
    rows = Language.connection.select_rows(
      "SELECT id, text FROM translation_strings WHERE tag = '#{from}'"
    )
    rows.each do |id, str|
      if from == "log_specimen_added"
        if str =~ /:specimen/
          str.sub!(/:specimen/, ":herbarium_record")
        else
          str.sub!(/:herbarium_record/, ":specimen")
        end
        str = Language.connection.quote(str)
        Language.connection.exec_query(
          "UPDATE translation_strings SET text = #{str} WHERE id = #{id}"
        )
      end
      Language.connection.execute(
        "UPDATE translation_strings SET tag = '#{to}' WHERE id = #{id}"
      )
    end
  end
end

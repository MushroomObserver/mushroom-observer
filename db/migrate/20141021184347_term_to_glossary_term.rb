class TermToGlossaryTerm < ActiveRecord::Migration[4.2]
  RENAME_STRINGS = {
    term: :glossary_term,
    TERM: :GLOSSARY_TERM,
    TERMS: :GLOSSARY_TERMS,
    terms: :glossary_terms,
    log_term_created_at: :log_glossary_term_created_at,
    log_term_updated_at: :log_glossary_term_updated_at,
    term_created_at: :glossary_term_created_at,
    term_updated_at: :glossary_term_updated_at,
    term_name: :glossary_term_name,
    term_description: :glossary_term_description,
    term_copyright_holder: :glossary_term_copyright_holder,
    term_copyright_warning: :glossary_term_copyright_warning,
    show_term: :show_glossary_term,
    show_term_title: :show_glossary_term_title,
    show_term_reuse_image: :show_glossary_term_reuse_image,
    show_term_remove_image: :show_glossary_term_remove_image,
    show_past_term_title: :show_past_glossary_term_title,
    show_past_term_no_version: :show_past_glossary_term_no_version,
    create_term: :create_glossary_term,
    create_term_add: :create_glossary_term_add,
    create_term_title: :create_glossary_term_title,
    term_index: :glossary_term_index,
    term_index_title: :glossary_term_index_title,
    term_index_intro: :glossary_term_index_intro,
    edit_term: :edit_glossary_term,
    edit_term_title: :edit_glossary_term_title,
    edit_term_save: :edit_glossary_term_save,
    edit_term_not_allowed: :edit_glossary_term_not_allowed
  }

  def update_translation_strings(current, desired)
    for id, tag in TranslationString.connection.select_rows %(
      SELECT id, tag FROM translation_strings
      WHERE tag = '#{current}' COLLATE utf8_bin
    )
      if tag == current.to_s
        TranslationString.connection.update %(
          UPDATE translation_strings SET tag = '#{desired}'
          WHERE id = #{id}
        )
      end
    end
  end

  def up
    rename_table :terms, :glossary_terms
    rename_table :terms_versions, :glossary_terms_versions
    rename_column :glossary_terms_versions, :term_id, :glossary_term_id

    rename_table :images_terms, :glossary_terms_images
    rename_column :glossary_terms_images, :term_id, :glossary_term_id

    rename_column :rss_logs, :term_id, :glossary_term_id

    RENAME_STRINGS.each do |k, v|
      update_translation_strings(k, v)
    end
  end

  def down
    RENAME_STRINGS.each do |k, v|
      update_translation_strings(v, k)
    end

    rename_column :rss_logs, :glossary_term_id, :term_id

    rename_column :glossary_terms_images, :glossary_term_id, :term_id
    rename_table :glossary_terms_images, :images_terms

    rename_column :glossary_terms_versions, :glossary_term_id, :term_id
    rename_table :glossary_terms_versions, :terms_versions
    rename_table :glossary_terms, :terms
  end
end

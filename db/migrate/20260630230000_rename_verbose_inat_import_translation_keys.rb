# frozen_string_literal: true

class RenameVerboseInatImportTranslationKeys < ActiveRecord::Migration[7.2]
  RENAMES = {
    inat_import_tracker_results: :results,
    inat_import_tracker_calculating_time: :calculating,
    inat_import_tracker_ended: :ended,
    inat_import_imported: :imported
  }.freeze

  def up
    TranslationString.rename_tags(RENAMES)
  end

  def down
    TranslationString.rename_tags(RENAMES.invert)
  end
end

# frozen_string_literal: true

# Update existing records with nil response_errors to empty string
# This is a data-only migration that doesn't attempt to set a database default,
# since MySQL doesn't allow defaults on TEXT columns.
# The InatImport model's after_initialize callback ensures new instances
# have response_errors initialized.
class UpdateNilResponseErrorsInInatImports < ActiveRecord::Migration[7.2]
  def up
    # Update existing records with nil response_errors to empty string
    execute <<-SQL.squish
      UPDATE inat_imports
      SET response_errors = ''
      WHERE response_errors IS NULL
    SQL
  end

  def down
    # No need to revert - leaving empty strings is fine
  end
end

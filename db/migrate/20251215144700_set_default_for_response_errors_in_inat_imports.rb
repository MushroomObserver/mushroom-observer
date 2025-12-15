# frozen_string_literal: true

# Set default value for response_errors column to empty string
# This ensures response_errors is never nil, addressing the root cause
# of the defensive nil check in InatImport#add_response_error
class SetDefaultForResponseErrorsInInatImports < ActiveRecord::Migration[7.2]
  def up
    change_column_default :inat_imports, :response_errors, from: nil, to: ""
    # Update existing records with nil response_errors to empty string
    InatImport.where(response_errors: nil).update_all(response_errors: "")
  end

  def down
    change_column_default :inat_imports, :response_errors, from: "", to: nil
  end
end

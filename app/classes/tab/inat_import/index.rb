# frozen_string_literal: true

# Link to the user's iNat imports index from the new-import form.
class Tab::InatImport::Index < Tab::Base
  def title
    :inat_imports.ti
  end

  def path
    inat_imports_path
  end
end

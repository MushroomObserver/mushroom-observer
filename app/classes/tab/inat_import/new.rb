# frozen_string_literal: true

# Link to the iNat-import new form (start a new import).
class Tab::InatImport::New < Tab::Base
  def title
    # Same label the Observations new/index pages use for this link.
    :create_observation_inat_import_link.l
  end

  def path
    new_inat_import_path
  end
end

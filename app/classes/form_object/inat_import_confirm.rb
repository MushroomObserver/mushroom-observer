# frozen_string_literal: true

# Form object for iNat import confirmation step.
# Carries form data through the confirmation page as hidden fields.
class FormObject::InatImportConfirm < FormObject::Base
  attribute :inat_username, :string
  attribute :inat_ids, :string
  attribute :import_all, :string
  attribute :consent, :string
end

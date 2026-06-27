# frozen_string_literal: true

# Form object for iNat import confirmation step.
# Carries form data through the confirmation page as hidden fields.
class FormObject::InatImportConfirm < FormObject::Base
  attribute :inat_username, :string
  attribute :inat_ids, :string
  attribute :import_all, :string
  attribute :consent, :string
  attribute :import_others, :string
  attribute :inat_url, :string
  attribute :original_inat_url, :string
  attribute :skip_inat_writeback, :string
end

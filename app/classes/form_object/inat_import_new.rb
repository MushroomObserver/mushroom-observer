# frozen_string_literal: true

# Form object for iNat import new/create form.
# Provides model for Superform field rendering and namespacing.
class FormObject::InatImportNew < FormObject::Base
  attribute :inat_username, :string
  attribute :inat_ids, :string
  attribute :all, :string
  attribute :consent, :string
end

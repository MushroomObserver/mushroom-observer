# frozen_string_literal: true

# Form object for requesting changes to taxonomic names
# Handles form data for name change request emails to admins
class FormObject::NameChangeRequest < FormObject::Base
  attribute :notes, :string
end

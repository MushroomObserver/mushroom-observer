# frozen_string_literal: true

# Form object for editing name synonyms
class FormObject::EditSynonym < FormObject::Base
  attribute :synonym_members, :string
  attribute :deprecate_all, :boolean, default: true
  # existing_synonyms and proposed_synonyms are dynamic hashes
  # handled via namespaces in the form component

  # Tell Superform to use PATCH method (this is an edit form)
  def persisted?
    true
  end
end

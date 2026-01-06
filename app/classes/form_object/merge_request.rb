# frozen_string_literal: true

# Form object for submitting a merge request email to admins
# Allows users to request merging two objects (e.g., names or locations)
class FormObject::MergeRequest < FormObject::Base
  attribute :notes, :string
end

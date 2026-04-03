# frozen_string_literal: true

# Form object for creating project field slips.
class FormObject::ProjectFieldSlip < FormObject::Base
  attribute :field_slips, :integer
  attribute :one_per_page, :boolean, default: false
end

# frozen_string_literal: true

# Backs `Components::InlineFilterForm` when filtering the field-slips
# index by project. The autocompleter shows project names; the
# hidden id field carries the chosen project's id to the controller.
class FormObject::FieldSlipFilter < FormObject::Base
  attribute :project_name, :string
  attribute :project, :integer
end

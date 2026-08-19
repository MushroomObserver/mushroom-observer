# frozen_string_literal: true

# Form object for the "show excluded observations" toggle on a
# project's Updates tab. Params namespaced as
# project_exclusions[show].
class FormObject::ProjectExclusions < FormObject::Base
  attribute :show, :boolean, default: false
end

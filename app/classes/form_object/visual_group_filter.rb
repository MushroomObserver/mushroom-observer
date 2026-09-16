# frozen_string_literal: true

# Form object for the status/filter-text controls on a visual group's
# edit page. Params namespaced as visual_group_filter[status],
# visual_group_filter[filter].
class FormObject::VisualGroupFilter < FormObject::Base
  attribute :status, :string, default: "needs_review"
  attribute :filter, :string
end

# frozen_string_literal: true

# Form object for the admin donations review form.
# No attributes needed — checkboxes are rendered manually.
class FormObject::ReviewDonations < FormObject::Base
  # Force PATCH method for Superform (updates existing records)
  def persisted?
    true
  end
end

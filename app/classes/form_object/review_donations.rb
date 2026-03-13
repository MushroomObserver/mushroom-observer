# frozen_string_literal: true

# Form object for the admin donations review form.
# Uses "Reviewed" as model name so Superform namespaces fields
# as reviewed[donation_id], matching controller expectations.
class FormObject::ReviewDonations < FormObject::Base
  def self.model_name
    ActiveModel::Name.new(self, nil, "Reviewed")
  end

  # Force PATCH method for Superform (updates existing records)
  def persisted?
    true
  end
end

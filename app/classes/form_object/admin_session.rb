# frozen_string_literal: true

# Form object for admin user switching form.
class FormObject::AdminSession < FormObject::Base
  attribute :user, :string
  attribute :user_id, :integer

  # Force Superform to use PATCH/PUT method (route expects PUT)
  def persisted?
    true
  end
end

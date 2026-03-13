# frozen_string_literal: true

# Form object for image vote anonymity updates
# This form has no fields - just displays counts and provides action buttons
class FormObject::ImageVoteAnonymity < FormObject::Base
  attr_accessor :num_anonymous, :num_public

  # Not persisted - this form triggers an action, doesn't save data
  def persisted?
    true # Return true so form uses PATCH method
  end
end

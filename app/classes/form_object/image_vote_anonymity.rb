# frozen_string_literal: true

# Form object for image vote anonymity updates
# This form has no fields - just displays counts and provides action buttons
class FormObject::ImageVoteAnonymity
  include ActiveModel::Model

  attr_accessor :num_anonymous, :num_public

  # Not persisted - this form triggers an action, doesn't save data
  def persisted?
    true # Return true so form uses PATCH method
  end

  # Override model_name to avoid params namespacing since we don't need it
  def self.model_name
    ActiveModel::Name.new(self, nil, "ImageVoteAnonymity")
  end
end

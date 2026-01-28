# frozen_string_literal: true

# Base class for email request form objects.
# Provides common attributes for forms that send emails.
class FormObject::EmailRequest < FormObject::Base
  attribute :subject, :string
  attribute :message, :string
  attribute :reply_to, :string # Optional: sender's email for replies

  def persisted?
    false
  end

  # Match common :email scope used by email forms
  def self.model_name
    ActiveModel::Name.new(self, nil, "email")
  end
end

# frozen_string_literal: true

# Form object for okay IPs management
# Handles adding new IPs to the okay list
class FormObject::OkayIps < FormObject::Base
  attribute :add_okay, :string
end

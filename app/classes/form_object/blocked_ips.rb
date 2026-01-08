# frozen_string_literal: true

# Form object for blocked IPs management
# Handles adding new IPs to the blocked list
class FormObject::BlockedIps < FormObject::Base
  attribute :add_bad, :string
end

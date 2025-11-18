# frozen_string_literal: true

# FormObject for editing user contribution bonuses (admin only).
# Allows admins to adjust user bonus points.
class FormObject::UserBonuses
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :val, :string

  def self.model_name
    ActiveModel::Name.new(self, nil, "UserBonuses")
  end
end

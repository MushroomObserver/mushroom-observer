# frozen_string_literal: true

class FormObject::FeatureEmail
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :content, :string

  def self.model_name
    ActiveModel::Name.new(self, nil, "FeatureEmail")
  end
end

# frozen_string_literal: true

# Form object for requesting herbarium curator access
class FormObject::HerbariumCuratorRequest
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :notes, :string

  def persisted?
    false
  end

  def self.model_name
    ActiveModel::Name.new(self, nil, "herbarium_curator_request")
  end
end

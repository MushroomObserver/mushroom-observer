# frozen_string_literal: true

# Form object for requesting herbarium curator access
class FormObject::HerbariumCuratorRequest < FormObject::Base
  attribute :notes, :string

  def persisted?
    false
  end
end

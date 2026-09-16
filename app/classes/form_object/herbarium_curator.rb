# frozen_string_literal: true

# Backs Herbaria::Show::AddCuratorForm.
class FormObject::HerbariumCurator < FormObject::Base
  attribute :login, :string
end

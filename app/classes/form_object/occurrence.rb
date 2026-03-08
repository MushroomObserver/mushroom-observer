# frozen_string_literal: true

# Form object for creating an Occurrence from selected observations.
class FormObject::Occurrence < FormObject::Base
  attribute :observation_id, :integer
  attribute :default_observation_id, :integer
end

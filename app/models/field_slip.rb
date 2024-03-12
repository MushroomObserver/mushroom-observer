# frozen_string_literal: true

class FieldSlip < ApplicationRecord
  belongs_to :observation
  belongs_to :project
end

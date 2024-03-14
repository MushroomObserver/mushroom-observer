# frozen_string_literal: true

class FieldSlip < ApplicationRecord
  belongs_to :observation
  belongs_to :project

  validates :code, uniqueness: true

  def code=(val)
    self[:code] = val.upcase
  end
end

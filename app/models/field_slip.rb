# frozen_string_literal: true

class FieldSlip < ApplicationRecord
  belongs_to :observation
  belongs_to :project

  validates :code, uniqueness: true
  validates :code, presence: true
  validate do |field_slip|
    unless field_slip.code.match(/[^\d.-]/)
      errors.add :code, :format, message: :field_slip_code_format_error.t
    end
  end

  def code=(val)
    self[:code] = val.upcase
    unless project
      prefix_match = code.match(/(^.+)[ -]\d+$/)
      if prefix_match
        self.project = Project.find_by(field_slip_prefix: prefix_match[1])
      end
    end
  end
end

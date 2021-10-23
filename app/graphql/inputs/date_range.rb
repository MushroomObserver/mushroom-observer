# frozen_string_literal: true

module Inputs
  class DateRange < Inputs::BaseInputObject
    description "Range of dates"
    argument :min, Types::Date, "Minimum value of the range", required: true
    argument :max, Types::Date, "Maximum value of the range", required: true

    def prepare
      min..max
    end
  end
end

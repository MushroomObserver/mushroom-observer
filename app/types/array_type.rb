# frozen_string_literal: true

class ArrayType < ActiveModel::Type::Value
  def cast(value)
    return [] if value.blank?

    [value].flatten
  end
end

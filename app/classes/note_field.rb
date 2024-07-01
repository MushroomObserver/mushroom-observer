# frozen_string_literal: true

# Simple PORO to help with structure notes
class NoteField
  attr_reader :name
  attr_reader :value

  def initialize(name:, value:)
    @name = name
    @value = value
  end

  def label
    name.to_s
  end
end

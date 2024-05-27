# frozen_string_literal: true

# limitations on Projects
class NoteField
  attr_reader :name

  def initialize(name:)
    @name = name
  end

  def label
    name
  end

  def value
    ""
  end
end

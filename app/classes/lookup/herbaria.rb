# frozen_string_literal: true

class Lookup::Herbaria < Lookup
  MODEL = Herbarium
  TITLE_COLUMN = :name

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    Herbarium.where(name: name)
  end
end

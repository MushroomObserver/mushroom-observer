# frozen_string_literal: true

class Lookup::Herbaria < Lookup
  MODEL = Herbarium
  TITLE_METHOD = :name

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    Herbarium.name_has(name)
  end
end

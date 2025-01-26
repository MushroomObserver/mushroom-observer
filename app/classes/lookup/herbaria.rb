# frozen_string_literal: true

class Lookup::Herbaria < Lookup
  def initialize(vals, params = {})
    super
    @model = Herbarium
    @name_column = :name
  end

  def lookup_method(name)
    Herbarium.where(name: name)
  end
end

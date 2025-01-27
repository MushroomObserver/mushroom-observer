# frozen_string_literal: true

class Lookup::Herbaria < Lookup
  def initialize(vals, params = {})
    @model = Herbarium
    @name_column = :name
    super
  end

  def lookup_method(name)
    Herbarium.where(name: name)
  end
end

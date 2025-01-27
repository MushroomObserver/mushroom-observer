# frozen_string_literal: true

class Lookup::SpeciesLists < Lookup
  def initialize(vals, params = {})
    @model = SpeciesList
    @name_column = :title
    super
  end

  def lookup_method(name)
    SpeciesList.where(title: name)
  end
end

# frozen_string_literal: true

class Lookup::SpeciesLists < Lookup
  def initialize(vals, params = {})
    super
    @model = SpeciesList
    @name_column = :title
  end

  def lookup_method(name)
    SpeciesList.where(title: name)
  end
end

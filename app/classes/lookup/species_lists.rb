# frozen_string_literal: true

class Lookup::SpeciesLists < Lookup
  MODEL = SpeciesList
  TITLE_METHOD = :title

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    SpeciesList.where(title: name)
  end
end

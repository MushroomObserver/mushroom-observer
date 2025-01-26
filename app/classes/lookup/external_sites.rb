# frozen_string_literal: true

class Lookup::ExternalSites < Lookup
  def initialize(vals, params = {})
    super
    @model = ExternalSite
    @name_column = :name
  end

  def lookup_method(name)
    ExternalSite.where(name: name)
  end
end

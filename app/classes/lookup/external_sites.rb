# frozen_string_literal: true

class Lookup::ExternalSites < Lookup
  def initialize(vals, params = {})
    @model = ExternalSite
    @title_column = :name
    super
  end

  def lookup_method(name)
    ExternalSite.where(name: name)
  end
end

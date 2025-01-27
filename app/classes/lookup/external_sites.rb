# frozen_string_literal: true

class Lookup::ExternalSites < Lookup
  MODEL = ExternalSite
  TITLE_COLUMN = :name

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    ExternalSite.where(name: name)
  end
end

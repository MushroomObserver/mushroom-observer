# frozen_string_literal: true

class Lookup::Regions < Lookup
  MODEL = Location
  TITLE_METHOD = :name

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    Location.region(name.to_s.clean_pattern)
  end
end

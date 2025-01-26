# frozen_string_literal: true

class Lookup::Regions < Lookup
  def initialize(vals, params = {})
    super
    @model = Location
  end

  def lookup_method(name)
    Location.in_region(name.to_s.clean_pattern)
  end
end

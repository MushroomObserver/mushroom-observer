# frozen_string_literal: true

class Lookup::Locations < Lookup
  MODEL = Location
  TITLE_COLUMN = :name

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    # Downcases and removes all punctuation, so it's a multi-string search
    # e.g. "sonoma co california usa"
    pattern = Location.clean_name(name.to_s).clean_pattern
    Location.name_has(pattern)
  end
end

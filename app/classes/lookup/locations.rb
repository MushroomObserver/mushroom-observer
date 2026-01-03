# frozen_string_literal: true

class Lookup::Locations < Lookup
  MODEL = Location
  TITLE_METHOD = :display_name

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    # Downcases and removes all punctuation, so it's a multi-string search
    # e.g. "sonoma co california usa"
    pattern = Location.clean_name(name.to_s).clean_pattern
    # Pick the shortest, most general name that matches everything.
    Location.shortest_names_with(pattern).limit(1)
  end
end

# frozen_string_literal: true

# NOTE: Not intended to be used to lookup observations by name.
# The class exists for reverse lookups: getting titles from a list of ids.
class Lookup::Observations < Lookup
  MODEL = Observation
  TITLE_METHOD = :unique_text_name

  def initialize(vals, params = {})
    super
  end

  # for compatibility only
  def lookup_method(name)
    Observation.where(title: name)
  end
end

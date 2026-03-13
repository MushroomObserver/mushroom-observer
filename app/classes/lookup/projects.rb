# frozen_string_literal: true

class Lookup::Projects < Lookup
  MODEL = Project
  TITLE_METHOD = :title

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    Project.title_has(name.to_s.clean_pattern)
  end
end

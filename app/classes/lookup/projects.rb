# frozen_string_literal: true

class Lookup::Projects < Lookup
  MODEL = Project
  TITLE_METHOD = :title

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    Project.where(title: name)
  end
end

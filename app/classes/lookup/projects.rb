# frozen_string_literal: true

class Lookup::Projects < Lookup
  def initialize(vals, params = {})
    super
    @model = Project
    @name_column = :title
  end

  def lookup_method(name)
    Project.where(title: name)
  end
end

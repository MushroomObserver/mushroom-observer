# frozen_string_literal: true

class Lookup::Projects < Lookup
  def initialize(vals, params = {})
    @model = Project
    @title_column = :title
    super
  end

  def lookup_method(name)
    Project.where(title: name)
  end
end

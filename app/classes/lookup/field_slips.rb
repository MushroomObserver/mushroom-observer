# frozen_string_literal: true

class Lookup::FieldSlips < Lookup
  MODEL = FieldSlip
  TITLE_COLUMN = :code

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    FieldSlip.where(code: name)
  end
end

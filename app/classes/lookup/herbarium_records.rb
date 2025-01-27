# frozen_string_literal: true

class Lookup::HerbariumRecords < Lookup
  MODEL = HerbariumRecord
  TITLE_COLUMN = :id

  def initialize(vals, params = {})
    super
  end

  def lookup_method(name)
    HerbariumRecord.where(id: name)
  end
end

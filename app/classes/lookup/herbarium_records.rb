# frozen_string_literal: true

class Lookup::HerbariumRecords < Lookup
  def initialize(vals, params = {})
    @model = HerbariumRecord
    @title_column = :id
    super
  end

  def lookup_method(name)
    HerbariumRecord.where(id: name)
  end
end

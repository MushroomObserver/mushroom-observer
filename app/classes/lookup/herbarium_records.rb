# frozen_string_literal: true

class Lookup::HerbariumRecords < Lookup
  def initialize(vals, params = {})
    super
    @model = HerbariumRecord
  end

  def lookup_method(name)
    HerbariumRecord.where(id: name)
  end
end

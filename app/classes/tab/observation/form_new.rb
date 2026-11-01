# frozen_string_literal: true

class Tab::Observation::FormNew < Tab::Collection
  def initialize(q_param: nil, index_filter: nil)
    super()
    @q_param = q_param
    @index_filter = index_filter
  end

  private

  def tabs
    [
      Tab::Observation::InatImport.new(q_param: @q_param),
      Tab::Observation::Index.new(index_filter: @index_filter)
    ]
  end
end

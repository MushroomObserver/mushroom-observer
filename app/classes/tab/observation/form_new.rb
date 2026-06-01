# frozen_string_literal: true

class Tab::Observation::FormNew < Tab::Collection
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  private

  def tabs
    [
      Tab::Observation::InatImport.new(q_param: @q_param),
      Tab::Observation::Index.new(q_param: @q_param)
    ]
  end
end

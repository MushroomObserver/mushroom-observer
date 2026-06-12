# frozen_string_literal: true

# Action-nav for the edit herbarium form — cancel-to-show + back-
# to-index.
class Tab::Herbarium::FormEdit < Tab::Collection
  def initialize(herbarium:, q_param: nil)
    super()
    @herbarium = herbarium
    @q_param = q_param
  end

  private

  def tabs
    [
      Tab::Herbarium::Return.new(herbarium: @herbarium),
      Tab::Herbarium::NonpersonalIndex.new(q_param: @q_param)
    ]
  end
end

# frozen_string_literal: true

# Action-nav for the new herbarium form — back-to-index link.
class Tab::Herbarium::FormNew < Tab::Collection
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  private

  def tabs
    [Tab::Herbarium::NonpersonalIndex.new(q_param: @q_param)]
  end
end

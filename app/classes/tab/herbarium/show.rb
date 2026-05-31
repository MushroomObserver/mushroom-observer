# frozen_string_literal: true

# Action-nav for the herbarium show page — just the back-to-index
# link.
class Tab::Herbarium::Show < Tab::Collection
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  private

  def tabs
    [Tab::Herbarium::NonpersonalIndex.new(q_param: @q_param)]
  end
end

# frozen_string_literal: true

# Action-nav on the sequence show page: back to parent observation.
class Tab::Sequence::ShowActions < Tab::Collection
  def initialize(sequence:)
    super()
    @sequence = sequence
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @sequence.observation)]
  end
end

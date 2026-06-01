# frozen_string_literal: true

class Tab::Observation::FormEdit < Tab::Collection
  def initialize(observation:)
    super()
    @observation = observation
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @observation)]
  end
end

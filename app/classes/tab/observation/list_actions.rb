# frozen_string_literal: true

# Action-nav for the species-lists-of-observation page — a single
# cancel-to-obs link. Replaces `observation_list_tabs`.
class Tab::Observation::ListActions < Tab::Collection
  def initialize(observation:)
    super()
    @observation = observation
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @observation)]
  end
end

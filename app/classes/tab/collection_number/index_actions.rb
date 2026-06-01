# frozen_string_literal: true

# Action-nav for the collection_numbers index page when scoped to a
# single observation: return to the observation + add a new collection
# number. Empty when no observation context.
class Tab::CollectionNumber::IndexActions < Tab::Collection
  def initialize(observation: nil)
    super()
    @observation = observation
  end

  private

  def tabs
    return [] if @observation.blank?

    [
      Tab::Object::Return.new(object: @observation),
      Tab::CollectionNumber::New.new(observation: @observation)
    ]
  end
end

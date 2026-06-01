# frozen_string_literal: true

# Action-nav for the collection_number new form: back to observation.
class Tab::CollectionNumber::FormNew < Tab::Collection
  def initialize(observation:)
    super()
    @observation = observation
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @observation)]
  end
end

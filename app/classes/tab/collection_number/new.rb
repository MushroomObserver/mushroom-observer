# frozen_string_literal: true

# "Create collection number for this observation" link.
class Tab::CollectionNumber::New < Tab::Base
  def initialize(observation:)
    super()
    @observation = observation
  end

  def title
    :create_collection_number.l
  end

  def path
    new_collection_number_path(observation_id: @observation.id)
  end

  def model
    CollectionNumber
  end
end

# frozen_string_literal: true

# "Add sequence to this observation" link.
class Tab::Sequence::New < Tab::Base
  def initialize(observation:)
    super()
    @observation = observation
  end

  def title
    :add_object.t(type: :sequence)
  end

  def path
    new_sequence_path(observation_id: @observation.id)
  end

  def model
    Sequence
  end
end

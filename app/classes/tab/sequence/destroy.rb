# frozen_string_literal: true

# "Destroy sequence" button-tab. After destroy, returns to the
# observation rather than the sequence index.
class Tab::Sequence::Destroy < Tab::Base
  def initialize(sequence:)
    super()
    @sequence = sequence
  end

  def title
    :destroy_object.t(type: :sequence)
  end

  def path
    @sequence
  end

  def html_options
    { button: :destroy,
      back: observation_path(@sequence.observation) }
  end

  def model
    @sequence
  end
end

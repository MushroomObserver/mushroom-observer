# frozen_string_literal: true

# "Edit sequence" link. `observation:` controls the `back` redirect
# target after editing — sends user back to the parent observation
# rather than the sequence show page.
class Tab::Sequence::Edit < Tab::Base
  def initialize(sequence:, observation:)
    super()
    @sequence = sequence
    @observation = observation
  end

  def title
    :EDIT.t
  end

  def path
    edit_sequence_path(id: @sequence.id, back: @observation.id)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @sequence
  end
end

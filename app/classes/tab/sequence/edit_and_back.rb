# frozen_string_literal: true

# "Edit sequence" link variant used on the sequence's own show page.
# `back: :show` returns to the sequence show page after edit.
class Tab::Sequence::EditAndBack < Tab::Base
  def initialize(sequence:)
    super()
    @sequence = sequence
  end

  def title
    :edit_object.t(type: :sequence)
  end

  def path
    @sequence.edit_link_args.merge(back: :show)
  end

  def model
    @sequence
  end
end

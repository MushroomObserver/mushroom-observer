# frozen_string_literal: true

# "Show this sequence" link. When `observation:` is set, narrows
# prev/next navigation to that observation's sequences via a scoped
# Query. Title is the truncated locus.
class Tab::Sequence::Show < Tab::Base
  def initialize(sequence:, observation: nil)
    super()
    @sequence = sequence
    @observation = observation
  end

  def title
    @sequence.locus.truncate(@sequence.locus_width).t
  end

  def path
    args = @sequence.show_link_args
    return args unless @observation

    args.merge(q: Query.lookup(:Sequence,
                               observations: @observation.id).q_param)
  end

  def alt_title
    :show_object.t(TYPE: Sequence)
  end

  def model
    @sequence
  end
end

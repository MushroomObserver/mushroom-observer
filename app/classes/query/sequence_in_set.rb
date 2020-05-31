# frozen_string_literal: true

class Query::SequenceInSet < Query::SequenceBase
  def parameter_declarations
    super.merge(
      ids: [Sequence]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end
end

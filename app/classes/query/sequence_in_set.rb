module Query
  # Sequences in a given set.
  class SequenceInSet < Query::SequenceBase
    def parameter_declarations
      super.merge(
        ids: [Sequence]
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("sequences")
      super
    end
  end
end

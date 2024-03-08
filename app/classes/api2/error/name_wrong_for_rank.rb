# frozen_string_literal: true

class API2
  # Taxon name isn't valid for the given rank.
  class NameWrongForRank < FatalError
    def initialize(str, rank)
      super()
      args.merge!(name: str.to_s, rank: :"rank_#{rank}")
    end
  end
end

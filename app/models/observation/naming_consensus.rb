# frozen_string_literal: true

class Observation
  class NamingConsensus
    attr_accessor :obs
    attr_accessor :namings
    attr_accessor :votes

    def initialize(obs)
      @obs = obs
      @namings = obs.namings
      @votes = @namings.map(&:votes).flatten
    end

    ############################################################################
    #
    #  :section: Preferred Naming
    #
    ############################################################################

    # Observation.user's unique preferred positive Name for this observation
    # Returns falsy if there's no unique preferred positive id
    # Used in show obs subtitle: owner_naming_line
    def owner_preference
      owner_uniq_favorite_name if owner_preference?
    end

    private

    # Does observation.user have a single preferred id for this observation?
    def owner_preference?
      owner_uniq_favorite_vote&.value&.>= Vote.owner_id_min_confidence
    end

    def owner_uniq_favorite_name
      favs = owner_favorite_votes
      favs[0].naming.name if favs.one?
    end

    def owner_uniq_favorite_vote
      votes = owner_favorite_votes
      votes.first if votes.one?
    end

    def owner_favorite_votes
      @votes.select { |v| v.user_id == @obs.user_id && v.favorite == true }
    end
  end
end

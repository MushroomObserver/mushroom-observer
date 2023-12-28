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

    # Observation.user's unique preferred positive Name for this observation
    # Returns falsy if there's no unique preferred positive id
    # Used on show_observation page
    # N+1: Bad news - this does several reloads of eager loaded votes.
    # Move this to the Election object.
    def owner_preference
      owner_uniq_favorite_name if owner_preference?
    end

    # Does observation.user have a single preferred id for this observation?
    def owner_preference?
      owner_uniq_favorite_vote&.value&.>= Vote.owner_id_min_confidence
    end

    def owner_uniq_favorite_name
      favs = owner_favorite_votes
      favs[0].naming.name if favs.count == 1
    end

    def owner_uniq_favorite_vote
      votes = owner_favorite_votes
      votes.first if votes.count == 1
    end

    def owner_favorite_votes
      @votes.select { |v| v.user_id == @obs.user_id && v.favorite == true }
    end

    ### end owner preference

    def users_vote(naming_id, user_id)
      votes.find { |v| v.naming_id == naming_id && v.user_id == user_id }
    end

    def users_favorite_vote(user_id)
      votes.find { |v| v.user_id == user_id && v.favorite }.value
    end

    def naming_of_vote(vote)
      namings.find { |n| n.id == vote.naming_id }
    end

    # and so on, basically provide methods for all of the accessors you need

    def change_users_vote_for_naming(naming_id, user_id, value)
      # various logic for demoting 100% votes etc. all using these three basal methods,
      # which are the only ones that actually use AR to change the database
      create_vote(naming_id, user_id, value)
      change_vote(vote, new_value)
      delete_vote(vote)
      # then at the end, recalculate the consensus, no reloading required
      calc_consensus
    end

    def create_vote(naming_id, user_id, value)
      votes << Vote.create(naming_id: naming_id, user_id: user_id, value: value)
    end

    def change_vote(vote, new_value)
      vote.update_attribute(value: new_value)
    end

    def delete_vote(vote)
      vote.destroy!
      votes.delete(vote)
    end

    def calculate_consensus
      # Uses local arrays of namings and votes, all guaranteed to be up to date
      # because the three methods above keep things up to date...
      # or if you really want, you can reload those arrays
      # now to see if anyone has voted in the meantime.
      reload_namings_and_votes!
      # do magic stuff
      # The update the observation.
      # obs.change_attributes(
      #   name_id: new_consensus_name_id,
      #   vote_cache: new_vote_cache
      # )
    end

    def reload_namings_and_votes!
      @namings = @obs.namings.include(:votes)
      @votes = @namings.map(&:votes).flatten
    end
  end
end

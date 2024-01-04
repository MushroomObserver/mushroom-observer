# frozen_string_literal: true

class Observation
  class NamingConsensus
    attr_accessor :observation
    attr_accessor :namings
    attr_accessor :votes

    def initialize(observation)
      @observation = observation
      @namings = observation.namings
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
      @votes.select do |v|
        v.user_id == @observation.user_id && v.favorite == true
      end
    end

    ############################################################################
    #
    #  :section: Namings and Votes
    #
    ############################################################################

    # Look up the corresponding instance in our namings association.  If we are
    # careful to keep all the operations within the tree of assocations of the
    # observations, we should never need to reload anything.
    # `find` here does not hit the db
    def lookup_naming(naming)
      # Disable cop; test suite chokes when the following "raise"
      # is re-written in "exploded" style (the Rubocop default)

      namings.find { |n| n == naming } ||
        raise(ActiveRecord::RecordNotFound.new(
                "Observation doesn't have naming with ID=#{naming.id}"
              ))
    end

    # # Dump out the situation as the observation sees it.  Useful for debugging
    # # problems with reloading requirements.
    # def dump_votes
    #   namings.map do |n|
    #     str = "#{n.id} #{n.name.real_search_name}: "
    #     if n.votes.empty?
    #       str += "no votes"
    #     else
    #       votes = n.votes.map do |v|
    #         "#{v.user.login}=#{v.value}" + (v.favorite ? "(*)" : "")
    #       end
    #       str += votes.join(", ")
    #     end
    #     str
    #   end.join("\n")
    # end

    public

    # CHECK: Don't need this in consensus?
    # Has anyone proposed a given Name yet for this observation?
    # Count is ok here because we have eager-loaded the namings.
    def name_been_proposed?(name)
      namings.any? { |n| n.name == name }
    end

    # Has the owner voted on a given Naming?
    def owner_voted?(naming)
      !lookup_naming(naming).users_vote(@observation.user).nil?
    end

    # Has a given User owner voted on a given Naming?
    def user_voted?(naming, user)
      !lookup_naming(naming).users_vote(user).nil?
    end

    # Get the owner's Vote on a given Naming.
    def owners_vote(naming)
      lookup_naming(naming).users_vote(@observation.user)
    end

    # Get a given User's Vote on a given Naming.
    def users_vote(naming, user)
      lookup_naming(naming).users_vote(user)
    end

    # Disable method name cops to avoid breaking 3rd parties' use of API

    # Returns true if a given Naming has received one of the highest positive
    # votes from the owner of this observation.
    # Note: multiple namings can return true for a given observation.
    # This is used to display eyes next to Proposed Name on Observation page
    def owners_favorite?(naming)
      lookup_naming(naming).users_favorite?(@observation.user)
    end

    # Returns true if a given Naming has received one of the highest positive
    # votes from the given user (among namings for this observation).
    # Note: multiple namings can return true for a given user and observation.
    def users_favorite?(naming, user)
      lookup_naming(naming).users_favorite?(user)
    end

    # All of observation.user's votes on all Namings for this Observation
    # Used in Observation and in tests
    def owners_votes
      user_votes(@observation.user)
    end

    # All of a given User's votes on all Namings for this Observation
    def user_votes(user)
      @namings.each_with_object([]) do |n, votes|
        v = n.users_vote(user)
        votes << v if v
      end
    end

    # Change User's Vote for this naming.  Automatically recalculates the
    # consensus for the Observation in question if anything is changed.
    # Returns true if something was changed.
    def change_vote(naming, value, user = User.current)
      result = false
      naming = lookup_naming(naming)
      vote = naming.users_vote(user)
      value = value.to_f

      if value == Vote.delete_vote
        result = delete_vote(naming, vote, user)

      # If no existing vote, or if changing value.
      elsif !vote || (vote.value != value)
        result = true
        process_real_vote(naming, vote, value, user)
      end

      # Update consensus if anything changed.
      calc_consensus if result

      result
    end

    def change_vote_with_log(naming, value)
      reload_namings_and_votes!
      change_vote(naming, value, naming.user)
      @observation.log(:log_naming_created, name: naming.format_name)
    end

    def calc_consensus
      reload_namings_and_votes!
      calculator = ::Observation::ConsensusCalculator.new(@namings)
      best, best_val = calculator.calc
      old = @observation.name
      if old != best || @observation.vote_cache != best_val
        # maybe use update here
        @observation.name = best
        @observation.vote_cache = best_val
        @observation.save
      end
      @observation.reload.announce_consensus_change(old, best) if best != old
    end

    # Try to guess which Naming is responsible for the consensus.  This will
    # always return a Naming, no matter how ambiguous, unless there are no
    # namings.
    def consensus_naming
      matches = find_matches
      return nil if matches.empty?
      return matches.first if matches.length == 1

      best_naming = matches.first
      best_value = matches.first.vote_cache
      matches.each do |naming|
        next unless naming.vote_cache > best_value

        best_naming = naming
        best_value = naming.vote_cache
      end
      best_naming
    end

    private

    def find_matches
      matches = @namings.select { |n| n.name_id == @observation.name_id }
      # n+1 - be sure observation name is eager loaded
      name = @observation.name
      return matches unless matches == [] && name && name.synonym_id

      @namings.select { |n| name.synonyms.include?(n.name) }
    end

    def format_coordinate(value, positive_point, negative_point)
      return "#{-value.round(4)}°#{negative_point}" if value.negative?

      "#{value.round(4)}°#{positive_point}"
    end

    def delete_vote(naming, vote, user)
      return false unless vote

      naming.votes.delete(vote)
      find_new_favorite(user) if vote.favorite
      true
    end

    def find_new_favorite(user)
      max = max_positive_vote(user)
      return unless max.positive?

      user_votes(user).each do |v|
        next if v.value != max || v.favorite

        v.favorite = true
        v.save
      end
    end

    def max_positive_vote(user)
      max = 0
      user_votes(user).each do |v|
        max = v.value if v.value > max
      end
      max
    end

    def process_real_vote(naming, vote, value, user)
      downgrade_totally_confident_votes(value, user)
      favorite = adjust_other_favorites(value, other_votes(vote, user))
      if vote
        vote.value = value
        vote.favorite = favorite
        vote.save
      else
        naming.votes.create!(
          user: user,
          observation: @observation,
          value: value,
          favorite: favorite
        )
      end
    end

    def downgrade_totally_confident_votes(value, user)
      # First downgrade any existing 100% votes (if casting a 100% vote).
      v80 = Vote.next_best_vote
      return if value <= v80

      user_votes(user).each do |v|
        next unless v.value > v80

        v.value = v80
        v.save
      end
    end

    def adjust_other_favorites(value, other_votes)
      favorite = false
      if value.positive?
        favorite = true
        other_votes.each do |v|
          if v.value > value
            favorite = false
            break
          end
          if (v.value < value) && v.favorite
            v.favorite = false
            v.save
          end
        end
      end

      # Will any other vote become a favorite?
      max_positive_value = (other_votes.map(&:value) + [value, 0]).max
      other_votes.each do |v|
        if (v.value >= max_positive_value) && !v.favorite
          v.favorite = true
          v.save
        end
      end
      favorite
    end

    def other_votes(vote, user)
      user_votes(user) - [vote]
    end

    ############################################################################
    #
    #  :section: Jason's Sketch
    #
    ############################################################################

    # def users_vote(naming_id, user_id)
    #   votes.find { |v| v.naming_id == naming_id && v.user_id == user_id }
    # end

    # def users_favorite_vote(user_id)
    #   # whatever the best way to iterate over all votes and
    #   # pick the one with the highest value
    #   votes.find { |v| v.user_id == user_id }.max
    # end

    # def naming_of_vote(vote)
    #   namings.find { |n| n.id == vote.naming_id }
    # end

    # # and so on, basically provide methods for all of the accessors you need

    # def change_users_vote_for_naming(naming_id, user_id, value)
    #   # various logic for demoting 100% votes etc. all using these three basal methods,
    #   # which are the only ones that actually use AR to change the database
    #   create_vote(naming_id, user_id, value)
    #   change_vote(vote, new_value)
    #   delete_vote(vote)
    #   # then at the end, recalculate the consensus, no reloading required
    #   calc_consensus
    # end

    # def create_vote(naming_id, user_id, value)
    #   votes << Vote.create(naming_id: naming_id, user_id: user_id, value: value)
    # end

    # def change_vote(vote, new_value)
    #   vote.update_attribute(value: new_value)
    # end

    # def delete_vote(vote)
    #   vote.destroy!
    #   votes.delete(vote)
    # end

    # def calculate_consensus
    #   # Uses local arrays of namings and votes, all guaranteed to be up to date
    #   # because the three methods above keep things up to date...
    #   # or if you really want, you can reload those arrays
    #   # now to see if anyone has voted in the meantime.
    #   reload_namings_and_votes!
    #   # do magic stuff
    #   # The update the observation.
    #   # obs.change_attributes(
    #   #   name_id: new_consensus_name_id,
    #   #   vote_cache: new_vote_cache
    #   # )
    # end

    public

    def reload_namings_and_votes!
      # @namings = @observation.namings.include(:votes)
      obs = ::Observation.naming_includes.find(@observation.id)
      @namings = obs.namings
      @votes = @namings.map(&:votes).flatten
    end
  end
end

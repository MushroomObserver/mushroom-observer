# frozen_string_literal: true

# Observation::NamingConsensus
#
# This PORO isolates the code that determines the current state of naming/
# voting on an obs, and handles naming and voting changes on observations.
#
# Instantiate a NamingConsensus to get a snapshot of the current state, or to
# perform changes to that state via proposing or voting on namings.
#
# The goal is to safeguard against any unintentional db loads whenever the
# observation's current "consensus" naming is calculated, which needs to
# happen whenever an observation is shown, or whenever namings or votes change,
# and the show_obs "namings_table" is redrawn.
#
# Instantiate this object with an observation that you've eager-loaded the
# namings and votes on. The PORO will use the eager-loaded associations, and
# only saves to the db when a naming or vote is changed/created. At this point,
# you need to call @consensus.reload_namings_and_votes! to update the object.
#
# The object itself contains everything needed to draw the Namings "table" -
# the views and controllers now should only access attributes and methods of a
# NamingConsensus object, because all the Naming and Vote methods that caused
# db lookups have been moved here.
#
#  name_been_proposed?::    Has someone proposed this Name already?
#  owners_votes::           Get all of the onwer's Vote's for this Observation.
#  owner_preference::       owners's unique prefered Name (if any) for this Obs
#  consensus_naming::       Guess which Naming is responsible for consensus.
#  calc_consensus::         Calculate and cache the consensus naming/name.
#  dump_votes::             Dump all the Naming and Vote info as known by this
#                           Observation and its associations.
#
# Methods that require passing a naming, called in views or controllers:
#  user_voted?::            Has a given User voted on this Naming?
#  owner_voted?::           Has the owner voted on a given Naming?
#  users_vote::             Get a given User's Vote on this Naming.
#  owners_vote::            Owner's Vote on a given Naming.
#  users_favorite?::        Is this Naming the given User's favorite?
#  owners_favorite?::       Is a given Naming one of the owner's favorite(s)?
#  change_vote::            Change a given User's Vote for a given Naming.
#  change_vote_with_log::   Also log the change (on the Obs)
#  editable?::              Can owner change this Naming's Name?
#  deletable?::             Can owner delete this Naming?
#  calc_vote_table::        Who voted on this naming (via VotesController#index)
#                           Note that many votes are anonymous, so...
#  clean_votes::            Delete unused votes (via NamingsController#update)
#  editable?::              Naming is editable?
#  deletable?::             Naming is deletable?
#
# At the time this was written, vote form updates performed something like
# 3N+2 db loads of naming votes per vote update (N in this case being the
# number of proposed namings per obs, so 3 namings meant 11 vote lookups).
# The vote table is the slowest table in the db, so it was extremely slow.
#
class Observation
  class NamingConsensus
    attr_accessor :observation, :namings, :votes

    def initialize(observation)
      @observation = observation
      @namings = observation.namings
      @votes = @namings.map(&:votes).flatten
    end

    def reload_namings_and_votes!
      obs = ::Observation.naming_includes.find(@observation.id)
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
      @votes.select do |v|
        v.user_id == @observation.user_id && v.favorite == true
      end
    end

    public

    ############################################################################
    #
    #  :section: Methods Used for Voting
    #
    ############################################################################

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

    # Has anyone proposed a given Name yet for this observation?
    # Count is ok here because we have eager-loaded the namings.
    def name_been_proposed?(name)
      namings.any? { |n| n.name == name }
    end

    # Has the owner voted on a given Naming?
    def owner_voted?(naming)
      !users_vote(naming, @observation.user).nil?
    end

    # Has a given User owner voted on a given Naming?
    def user_voted?(naming, user)
      !users_vote(naming, user).nil?
    end

    # Get the owner's Vote on a given Naming.
    def owners_vote(naming)
      users_vote(naming, @observation.user)
    end

    # Get a given User's Vote on a given Naming.
    def users_vote(naming, user)
      votes.select do |v|
        return v if v.user_id == user.id && v.naming_id == naming.id
      end
      nil
    end

    # Has anyone voted (positively) on this?  We don't want people changing
    # the name for namings that the community has voted on.
    # Returns true if no one has.
    def editable?(naming)
      naming.votes.each do |v|
        return false if v.user_id != naming.user_id && v.value.positive?
      end
      true
    end

    # Has anyone given this their strongest (positive) vote?
    # We don't want people destroying namings that someone else likes best.
    # Returns true if no one has.
    def deletable?(naming)
      naming.votes.each do |v|
        if v.user_id != naming.user_id && v.value.positive? && v.favorite
          return false
        end
      end
      true
    end

    # Returns true if a given Naming has received one of the highest positive
    # votes from the owner of this observation.
    # Note: multiple namings can return true for a given observation.
    # This is used to display eyes next to Proposed Name on Observation page
    def owners_favorite?(naming)
      users_favorite?(naming, @observation.user)
    end

    # Returns true if a given Naming has received one of the highest positive
    # votes from the given user (among namings for this observation).
    # Note: multiple namings can return true for a given user and observation.
    def users_favorite?(naming, user)
      votes.any? do |v|
        v.user_id == user.id && v.naming_id == naming.id && v.favorite
      end
    end

    # All of observation.user's votes on all Namings for this Observation
    # Used in Observation and in tests
    def owners_votes
      user_votes(@observation.user)
    end

    # All of a given User's votes on all Namings for this Observation
    def user_votes(user)
      @namings.each_with_object([]) do |n, votes|
        v = users_vote(n, user)
        votes << v if v
      end
    end

    # Used by NamingsController#update
    def clean_votes(naming, new_name, user)
      return unless new_name != naming.name

      naming.votes.each do |vote|
        vote.destroy if vote.user_id != user.id
      end
    end

    # Generate a table the number of User's who cast each level of Vote for a
    # single Naming. (This refreshes the naming.vote_cache while it's at it.)
    #
    #   table = consensus.calc_vote_table(naming)
    #   for key, record in table
    #     str    = key.l
    #     num    = record[:num]    # Number of users who voted near this level.
    #     weight = record[:wgt]    # Sum of users' weights.
    #     value  = record[:value]  # Value of this vote level (arbitrary scale)
    #     votes  = record[:votes]  # List of actual votes.
    #   end
    #
    # only executed on VotesController#index
    def calc_vote_table(naming)
      # Initialize table.
      table = {}
      Vote.opinion_menu.each do |str, val|
        table[str] = {
          num: 0,
          wgt: 0.0,
          value: val,
          votes: []
        }
      end

      # Gather votes, doing a weighted sum in the process.
      tot_sum = 0
      tot_wgt = 0
      naming.votes.each do |v|
        str = Vote.confidence(v.value)
        wgt = v.user_weight
        table[str][:num] += 1
        table[str][:wgt] += wgt
        table[str][:votes] << v
        tot_sum += v.value * wgt
        tot_wgt += wgt
      end
      val = tot_sum.to_f / (tot_wgt + 1.0)

      # Update vote_cache if it's wrong.
      naming.update!(vote_cache: val) if (naming.vote_cache - val).abs > 1e-4

      table
    end

    # Change User's Vote for this naming.  Automatically recalculates the
    # consensus for the Observation in question if anything is changed.
    # Returns true if something was changed.
    # Called from outside.
    def change_vote(naming, value, user = User.current)
      result = false
      vote = users_vote(naming, user)
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

    # Recalculates consensus_naming and saves the observation accordingly.
    # Resets the `needs_naming` column based on current naming specificity
    # and confidence. Also initiates the email blast to interested parties.
    def calc_consensus
      reload_namings_and_votes!
      calculator = ::Observation::ConsensusCalculator.new(@namings)
      best, best_val = calculator.calc
      old = @observation.name
      if old != best || @observation.vote_cache != best_val
        needs_naming = best.above_genus? && best_val.positive? ? 0 : 1
        @observation.update(name: best, vote_cache: best_val,
                            needs_naming: needs_naming)
        mark_obs_reviewed
      end
      @observation.reload.announce_consensus_change(old, best) if best != old
    end

    # We interpret any naming vote to mean the user has reviewed the obs.
    # Setting this here makes the identify index query much cheaper.
    def mark_obs_reviewed
      if (view = ObservationView.find_by(observation_id: @observation.id,
                                         user_id: User.current_id))
        view.update!(last_view: Time.zone.now, reviewed: 1)
      else
        ObservationView.create!(observation_id: @observation.id,
                                user_id: User.current_id,
                                last_view: Time.zone.now, reviewed: 1)
      end
    end

    # Try to guess which Naming is responsible for the consensus.
    # This will always return a Naming, no matter how ambiguous,
    # unless there are no namings.
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

    def delete_vote(naming, vote, user)
      return false unless vote

      naming.votes.delete(vote)
      reload_namings_and_votes!
      find_new_favorite(user) if vote.favorite
      true
    end

    def find_new_favorite(user)
      max = max_positive_vote(user)
      return unless max.positive?

      user_votes(user).each do |v|
        next if v.value != max || v.favorite

        v.update(favorite: true)
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
  end
end

# frozen_string_literal: true

# Vote::WeightBoost
#
# Computes effective vote weights with the sub-max vote boost
# (Issue #3815). When a user's highest vote is positive but below
# MAXIMUM_VOTE, equals their max across all namings, and the
# naming already has a higher vote from someone else, the weight
# is reduced proportionally. This treats the sub-max vote as
# diluted agreement at the naming's highest level rather than
# penalizing it.
#
# Used by ConsensusCalculator, MergedNaming, and NamingConsensus
# to ensure consistent vote_cache calculations.
#
class Vote::WeightBoost
  def initialize(namings)
    @user_max_votes = {}
    @naming_max_votes = {}
    precompute(namings)
  end

  def effective_weight(user_id, val, wgt, naming_id)
    return wgt unless boost_vote?(user_id, val, naming_id)

    naming_max = @naming_max_votes[naming_id]
    (val.abs / naming_max.to_f) * wgt
  end

  private

  def precompute(namings)
    namings.each do |naming|
      naming_max = 0
      naming.votes.each do |vote|
        uid = vote.user_id
        val = vote.value
        naming_max = val if val > naming_max
        next if @user_max_votes[uid] &&
                @user_max_votes[uid] >= val

        @user_max_votes[uid] = val
      end
      @naming_max_votes[naming.id] = naming_max
    end
  end

  def boost_vote?(user_id, val, naming_id)
    user_max = @user_max_votes[user_id]
    naming_max = @naming_max_votes[naming_id]
    user_max&.positive? &&
      user_max < Vote::MAXIMUM_VOTE &&
      val == user_max &&
      naming_max > val
  end
end

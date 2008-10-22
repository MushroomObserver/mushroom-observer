#
#  Model describing a single vote for a single Naming.  Properties:
#
#  1. has a value
#  2. belongs to a User, Naming, and Observation
#
#  Very simple.  Right?  Well, I've complicated things by distributing
#  vote-related functionality over three classes: Observation, Naming, and
#  Vote.  Important methods in other classes are:
#
#  * Observation#calc_consensus      Decide which Name is winner.
#  * Observation#refresh_vote_cache  Refresh vote cache for all Observation's.
#  * Naming#change_vote              Change a User's Vote for a given Naming.
#  * Naming#is_users_favorite?(user) Is this Naming the given User's favorite?
#  * Naming#calc_vote_table          
#
#  Public:
#    Vote.confidence_menu    Structures needed by the form helper,
#    Vote.agreement_menu     select(), to create a pulldown menu.
#
#    Vote.confidence(value)  Find vote closest in value to the
#    Vote.agreement(value)   given one.  Returns string.
#    obj.confidence
#    obj.agreement
#
#    obj.user_weight         Calculate weight from user's contribution.
#
#    Vote.delete_vote    Value of the special "delete" vote.
#    Vote.minimum_vote   Value of the weakest nonzero vote.
#    Vote.min_neg_vote   Value of the least negative vote.
#    Vote.average_vote   Value of the neutral vote.
#    Vote.min_pos_vote   Value of the least positive vote.
#    Vote.next_best_vote Value of the next-to-best vote.
#    Vote.maximum_vote   Value of the strongest vote.
#    Note: larger vote value indicates stronger agreement
#
#  Protected:
#    Vote.lookup_value(val, list)    Used by confidence/agreement().
#
################################################################################

class Vote < ActiveRecord::Base
  belongs_to :user
  belongs_to :naming
  belongs_to :observation

  LOG10 = Math.log(10)

  CONFIDENCE_VALS = [
    [ :vote_confidence_100,  3 ],
    [ :vote_confidence_80,   2 ],
    [ :vote_confidence_60,   1 ],
    [ :vote_confidence_40,  -1 ],
    [ :vote_confidence_20,  -2 ],
    [ :vote_confidence_0,   -3 ]
  ]

  AGREEMENT_VALS = [
    [ :vote_no_opinion,     0 ],
    [ :vote_agreement_100,  3 ],
    [ :vote_agreement_80,   2 ],
    [ :vote_agreement_60,   1 ],
    [ :vote_agreement_40,  -1 ],
    [ :vote_agreement_20,  -2 ],
    [ :vote_agreement_0,   -3 ]
  ]

  # Various useful vote values.
  DELETE_VOTE    = 0
  MINIMUM_VOTE   = -3
  MIN_NEG_VOTE   = -2
  AVERAGE_VOTE   = -1
  MIN_POS_VOTE   =  1
  NEXT_BEST_VOTE =  2
  MAXIMUM_VOTE   =  3

  #--
  # External access to the constants above.
  def self.delete_vote;    DELETE_VOTE;    end # This is used to mean "delete my vote". 
  def self.minimum_vote;   MINIMUM_VOTE;   end # Weakest nonzero vote.
  def self.min_neg_vote;   MIN_NEG_VOTE;   end # Least-negative vote.
  def self.average_vote;   AVERAGE_VOTE;   end # Neutral vote.
  def self.min_pos_vote;   MIN_POS_VOTE;   end # Least-positive vote.
  def self.next_best_vote; NEXT_BEST_VOTE; end # Next-to-best vote.
  def self.maximum_vote;   MAXIMUM_VOTE;   end # Strongest vote.

  # Return list of menu options.
  def self.confidence_menu; CONFIDENCE_VALS; end
  def self.agreement_menu;  AGREEMENT_VALS;  end

  # Find label of closest value in the enumerated lists above.
  def self.confidence(val); return Vote.lookup_value(val, CONFIDENCE_VALS);        end
  def self.agreement(val);  return Vote.lookup_value(val, AGREEMENT_VALS);         end
  def confidence;           return Vote.lookup_value(self.value, CONFIDENCE_VALS); end
  def agreement;            return Vote.lookup_value(self.value, AGREEMENT_VALS);  end
  #++

  # Calculate user weight from cotribution score.
  def user_weight
    contrib = self.user ? self.user.contribution : 0
    contrib = contrib < 1 ? 0 : Math.log(contrib) / LOG10
    contrib += 1 if self.observation && self.user == self.observation.user
    return contrib
  end

  protected

  # Find label of closest value in a given enumerated lists.
  def self.lookup_value(val, list)
    last_pair = nil
    for pair in list
      if pair[1] != 0
        if !last_pair.nil? && val > (last_pair[1] + pair[1]) / 2
          return last_pair[0]
        end
        last_pair = pair
      end
    end
    return last_pair[0]
  end

  def validate # :nodoc:
    if !self.naming
      errors.add(:naming, :validate_vote_naming_missing.t)
    end
    if !self.user
      errors.add(:user, :validate_vote_user_missing.t)
    end

    if self.value.nil?
      errors.add(:value, :validate_vote_value_missing.t)
    elsif self.value_before_type_cast.to_s !~ /^[+-]?\d+(\.\d+)?$/
      errors.add(:value, :validate_vote_value_not_integer.t)
    elsif self.value < MINIMUM_VOTE || self.value > MAXIMUM_VOTE
      errors.add(:value, :validate_vote_value_out_of_bounds.t)
    end
  end
end

#
#  = Vote Model
#
#  Model describing a single vote for a single Naming.
#
#  Very simple.  Right?  Well, I've complicated things by distributing
#  vote-related functionality over three classes: Observation, Naming, and
#  Vote.  Important methods in other classes are:
#
#  Observation#calc_consensus::      Decide which Name is winner.
#  Observation#refresh_vote_cache::  Refresh vote cache for all Observation's.
#  Naming#change_vote::              Change a User's Vote for a given Naming.
#  Naming#is_users_favorite?::       Is this Naming the given User's favorite?
#  Naming#calc_vote_table::          ???
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1.
#  sync_id::            Globally unique alphanumeric id, used to sync with remote servers.
#  created::            Date/time it was first created.
#  modified::           Date/time it was last modified.
#  user::               User that created it.
#  value::              Value of vote, float, e.g.: 3.0 = 100%, -3.0 = -100%
#  naming::             Naming we're voting on.
#  observation::        Observation the Naming belongs to.
#
#  == Class methods
#
#  ==== Vote values
#  delete_vote::        Value of the special "delete" vote.
#  minimum_vote::       Value of the weakest nonzero vote.
#  min_neg_vote::       Value of the least negative vote.
#  min_pos_vote::       Value of the least positive vote.
#  next_best_vote::     Value of the next-to-best vote.
#  maximum_vote::       Value of the strongest vote.
#
#  ==== Other
#  confidence_menu::    Structures needed by the form helper,
#  agreement_menu::     select(), to create a pulldown menu.
#  confidence::         Find vote closest in value to the
#  agreement::          given one.  Returns string.
#
#  == Instance methods
#
#  confidence::         Find vote closest in value to the
#  agreement::          given one.  Returns string.
#  user_weight::        Calculate weight from user's contribution.
#
#  == Callbacks
#
#  None.
#
################################################################################

class Vote < ActiveRecord::MO
  belongs_to :user
  belongs_to :naming
  belongs_to :observation

  # ----------------------------
  #  :section: Values
  # ----------------------------

  DELETE_VOTE    =  0
  MINIMUM_VOTE   = -3
  MIN_NEG_VOTE   = -1
  MIN_POS_VOTE   =  1
  NEXT_BEST_VOTE =  2
  MAXIMUM_VOTE   =  3

  # This is used to mean "delete my vote".
  def self.delete_vote
    DELETE_VOTE
  end

  # Weakest nonzero vote.
  def self.minimum_vote
    MINIMUM_VOTE
  end

  # Least-negative vote.
  def self.min_neg_vote
    MIN_NEG_VOTE
  end

  # Least-positive vote.
  def self.min_pos_vote
    MIN_POS_VOTE
  end

  # Next-to-best vote.
  def self.next_best_vote
    NEXT_BEST_VOTE
  end

  # Strongest vote.
  def self.maximum_vote
    MAXIMUM_VOTE
  end

  # ----------------------------
  #  :section: Labels
  # ----------------------------

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

  # List of options interpreted as "confidence".
  #
  #   for label, value in Vote.confidence_menu
  #     puts "#{label.l} #{value}"
  #   end
  #
  def self.confidence_menu
    CONFIDENCE_VALS
  end

  # List of options interpreted as "agreement".
  #
  #   for label, value in Vote.agreement_menu
  #     puts "#{label.l} #{value}"
  #   end
  #
  def self.agreement_menu
    AGREEMENT_VALS
  end

  # Find label of closest value in the "confidence" menu.
  def self.confidence(val)
    lookup_value(val, CONFIDENCE_VALS)
  end

  # Find label of closest value in the "agreement" menu.
  def self.agreement(val)
    lookup_value(val, AGREEMENT_VALS)
  end

  # Find label of closest value in the "confidence" menu.
  def confidence
    self.class.lookup_value(value, CONFIDENCE_VALS)
  end

  # Find label of closest value in the "agreement" menu.
  def agreement
    self.class.lookup_value(value, AGREEMENT_VALS)
  end

  # ----------------------------
  #  :section: Weights
  # ----------------------------

  LOG10 = Math.log(10)

  # Calculate user weight from contribution score.  Weight is logarithmic:
  #
  #   weight = log10(contribution) + 1   # owner of observation
  #   weight = log10(contribution)       # all other users
  #   weight = 0                         # if contribution <= 1
  #
  def user_weight
    contrib = user ? user.contribution : 0
    contrib = contrib < 1 ? 0 : Math.log(contrib) / LOG10
    contrib += 1 if observation && user == observation.user
    return contrib
  end

################################################################################

protected

  # Find label of closest value in a given enumerated lists.
  def self.lookup_value(val, list) # :nodoc:
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
    if !self.user && !User.current
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

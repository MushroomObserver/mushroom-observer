# frozen_string_literal: true

#
#  = Vote Model
#
#  Model describing a single vote for a single Naming.  Methods for dealing
#  with Vote's are all moved up to Naming or Observation::NamingConsensus,
#  depending on whether all the information required for the operation is
#  contained within a single Naming or not.
#  Vote is responsible for very little except holding the value.
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1.
#  created_at::         Date/time it was first created.
#  updated_at::         Date/time it was last updated.
#  user::               User that created it.
#  value::              Value of Vote, a Float: 3.0 = 100%, -3.0 = -100%
#  naming::             Naming we're voting on.
#  observation::        Observation the Naming belongs to.
#  favorite::           Is this the User's favorite Vote for this Observation?
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
#  percent::            Convert value to percentage.
#
#  ==== Vote labels
#  confidence_menu::    Structure used by form helper +select+
#                       to create pulldown menu.
#  confidence::         Classify value as confidence level, String.
#
#  == Instance methods
#
#  percent::            Return value as percentage.
#  user_weight::        Calculate weight from user's contribution.
#
#  == Callbacks
#
#  None.
#
################################################################################

class Vote < AbstractModel
  belongs_to :user
  belongs_to :naming
  belongs_to :observation

  scope :by_user, lambda { |user|
    user_id = user.is_a?(Integer) ? user : user&.id
    where(user_id: user_id)
  }
  # scope :not_by_user, lambda { |user|
  #   user_id = user.is_a?(Integer) ? user : user&.id
  #   where.not(user_id: user_id)
  # }

  # ----------------------------
  #  :section: Values
  # ----------------------------

  DELETE_VOTE    = 0
  MINIMUM_VOTE   = -3
  MIN_NEG_VOTE   = -1
  MIN_POS_VOTE   =  1
  NEXT_BEST_VOTE =  2
  MAXIMUM_VOTE   =  3

  def self.construct(args, naming)
    now = Time.zone.now
    vote = Vote.new
    vote.assign_attributes(args.permit(:favorite, :value)) if args
    vote.created_at = now
    vote.updated_at = now
    vote.user = @user
    vote.naming = naming
    vote.observation = naming.observation
    vote
  end

  # Override the default show_controller
  def self.show_controller
    "/observations"
  end

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

  # minimum owner's vote needed to display owner_id
  def self.owner_id_min_confidence
    min_pos_vote
  end

  # Convert a given Vote value to a percentage.
  def self.percent(val)
    return 0.0 if val.blank?

    val.to_f * 100 / 3
  end

  # Convert Vote's value to a percentage.
  def percent
    self.class.percent(value)
  end

  # Validate a vote value.  Returns Float value if valid, nil otherwise.
  def self.validate_value(val)
    val = val.to_f
    val && val >= MINIMUM_VOTE && val <= MAXIMUM_VOTE ? val : nil
  rescue StandardError
    nil
  end

  # ----------------------------
  #  :section: Labels
  # ----------------------------

  CONFIDENCE_VALS = [
    [:vote_confidence_100,  3.0],
    [:vote_confidence_80,   2.0],
    [:vote_confidence_60,   1.0],
    [:vote_confidence_40,  -1.0],
    [:vote_confidence_20,  -2.0],
    [:vote_confidence_0,   -3.0]
  ].freeze

  NO_OPINION_VAL = [:vote_no_opinion, 0].freeze

  # Force unit tests to verify existence of these translations.
  if false
    :vote_confidence_100.l
    :vote_confidence_80.l
    :vote_confidence_60.l
    :vote_confidence_40.l
    :vote_confidence_20.l
    :vote_confidence_0.l
    :vote_no_opinion.l
  end

  # List of options interpreted as "confidence".
  #
  #   for label, value in Vote.confidence_menu
  #     puts "#{label.l} #{value}"
  #   end
  #
  def self.confidence_menu
    translate_menu(CONFIDENCE_VALS)
  end

  def self.no_opinion
    :vote_no_opinion.l
  end

  def self.opinion_menu
    translate_menu([NO_OPINION_VAL] + confidence_menu)
  end

  # Find label of closest value in the "confidence" menu.
  def self.confidence(val)
    lookup_value(val, confidence_menu)
  end

  # ----------------------------
  #  :section: Other
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
    contrib += 1 if observation && user_id == observation.user_id
    contrib
  end

  # I want to turn this silly logic into an explicit boolean in the table.
  # This is the first step: abstracting it as a method on Vote instance.
  # Now we are free to change the implementation later.
  def anonymous?
    (user.votes_anonymous == "yes") ||
      (user.votes_anonymous == :old &&
       updated_at <= Time.zone.parse(MO.vote_cutoff))
  end

  # Used by script/refresh_caches
  # Mark an observation as `reviewed` by a user if they've already voted on it.
  # (The user can also independently "mark as reviewed" in the help-identify
  # UI, so this cronjob should not reset any obs to "not reviewed".)
  #
  # This method makes a hash of all votes, keyed by observation and user, and
  # stores the `updated_at` as the value, in case we need to create a new
  # `ObservationView` record. Next, we load all ObservationViews, keyed by
  # observation and user, and if an observation_view with `reviewed == true`
  # matches the key of the working hash, we reset all those values to `1`.
  # All remaining hashes with a non-`1` value will either need to set the
  # corresponding `observation_view` with `reviewed: true`, or create a new OV.
  def self.update_observation_views_reviewed_column
    working_hash = {}
    # Because of anonymous voting, many votes have user_id: 0 and are useless
    # for setting `reviewed` status. Filter those out.
    # Store the updated_at as the value (in case we need a new OV)
    Vote.where.not(user_id: 0).
      select(:observation_id, :user_id, :updated_at).each do |v|
      working_hash[[v.observation_id, v.user_id]] = v.updated_at
    end

    ObservationView.where(reviewed: true).
      select(:observation_id, :user_id).each do |ov|
      if working_hash[[ov.observation_id, ov.user_id]].present?
        working_hash[[ov.observation_id, ov.user_id]] = 1
      end
    end

    # Remove where we've already got it reviewed.
    working_hash.reject { |_k, v| v == 1 }

    working_hash.each do |k, v|
      ov = ObservationView.find_by(observation_id: k[0], user_id: k[1])
      if ov
        ov.update!(reviewed: 1)
      else
        ObservationView.create!(observation_id: k[0], user_id: k[1],
                                last_viewed: v, reviewed: 1)
      end
    end
  end

  ##############################################################################

  protected

  # Find label of closest value in a given enumerated lists.
  def self.lookup_value(val, list) # :nodoc:
    last_pair = nil
    list.each do |pair|
      next unless pair[1] != 0
      if !last_pair.nil? && val > (last_pair[1] + pair[1]) / 2
        return last_pair[0]
      end

      last_pair = pair
    end
    last_pair[0]
  end

  validate :check_requirements
  def check_requirements # :nodoc:
    errors.add(:naming, :validate_vote_naming_missing.t) unless naming
    errors.add(:user, :validate_vote_user_missing.t) if !user && !User.current

    if value.nil?
      errors.add(:value, :validate_vote_value_missing.t)
    elsif !/^[+-]?\d+(\.\d+)?$/.match?(value_before_type_cast.to_s)
      errors.add(:value, :validate_vote_value_not_integer.t)
    elsif value < MINIMUM_VOTE || value > MAXIMUM_VOTE
      errors.add(:value, :validate_vote_value_out_of_bounds.t)
    end
  end

  ##############################################################################

  # private class methods

  def self.translate_menu(menu)
    result = []
    menu.each do |k, v|
      result << [(k.is_a?(Symbol) ? k.l : k.to_s), v]
    end
    result
  end

  private_class_method :translate_menu
end

#
#  = Naming Model
#
#  Naming's are used to associate a proposed Name with an Observation.  An
#  Observation generally has one or more Naming's, but it can also have none,
#  meaning that it is unidentified.
#
#  == Attributes
#
#  id::                     Locally unique numerical id, starting at 1.
#  sync_id::                Globally unique alphanumeric id, used to sync with remote servers.
#  created::                Date/time it was created.
#  modified::               Date/time it was last modified.
#  user::                   User that created it.
#  observation::            Observation it is attached to.
#  name::                   Name it refers to.
#  vote_cache::             Weighted sum of votes for this Naming, cached.
#  reasons::                Serialized Hash containing reasons.
#
#  == Class methods
#
#  None.
#
#  == Instance methods
#
#  ==== Formatting
#  text_name::              Plain text.  (uses name.search_name)
#  format_name::            Textilized.  (uses name.observation_name)
#  unique_text_name::       Same as above, with id added to make unique.
#  unique_format_name::     Same as above, with id added to make unique.
#
#  ==== Voting
#  votes::                  List of Vote's attached to this Naming.
#  vote_sum::               Straight sum of Vote's for this Naming.
#  vote_percent::           Convert cached Vote score to a percentage.
#  user_voted?::            Has a given User voted on this Naming?
#  users_vote::             Get a given User's Vote on this Naming.
#  is_users_favorite?::     Is this Naming the given User's favorite?
#  editable?::              Can owner change this Naming's Name?
#  deletable?::             Can owner delete this Naming?
#  calc_vote_table::        (Used by show_votes.rhtml.)
#
#  == Callbacks
#
#  did_name_change?::       Check if name changed before saving.
#  create_emails::          Notify users of changes after saving.
#  log_destruction::        Log destruction after destroying it.
#  enforce_default_reasons:: Make sure default reasons are set in if none given.
#
################################################################################

class Naming < AbstractModel
  belongs_to :observation
  belongs_to :name
  belongs_to :user
  has_many   :votes, :dependent => :destroy

  serialize :reasons

  before_save   :did_name_change?
  before_save   :enforce_default_reasons
  after_save    :create_emails
  after_destroy :log_destruction

  # Return name in plain text.
  def text_name
    name ? name.search_name : ''
  end

  # Return name in plain text (with id tacked on to make unique).
  def unique_text_name
    "%s (%s)" % [text_name, id]
  end

  # Return name in Textile format.
  def format_name
    name ? name.observation_name : ''
  end

  # Return name in Textile format (with id tacked on to make unique).
  def unique_format_name
    "%s (%s)" % [format_name, id]
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # Detect name changes in namings
  def did_name_change?
    @name_changed = name_id_changed?
    return true
  end

  # Send email notifications after creating or changing the Name.
  def create_emails
    if @name_changed
      @name_changed = false

      # Send email to people interested in this name.
      @initial_name_id = self.name_id
      taxa = self.name.all_parents
      taxa.push(self.name)
      for taxon in taxa
        for n in Notification.find_all_by_flavor_and_obj_id(:name, taxon.id)
          if n.user.created_here
            QueuedEmail::NameTracking.create_email(n, self)
          end
        end
      end

      # Send email to people interested in this observation.
      if obs = self.observation
        owner  = obs.user
        sender = self.user
        recipients = []

        # Send notification to owner if they want.
        recipients.push(owner) if owner && owner.email_observations_naming

        # Send to people who have registered interest in this observation.
        # Also remove everyone who has explicitly said they are NOT interested.
        for interest in obs.interests
          if interest.state
            recipients.push(interest.user)
          else
            recipients.delete(interest.user)
          end
        end

        # Also send to people who have registered positive interest in this name.
        # (Don't want *disinterest* in name overriding interest in the observation, say.)
        for taxon in taxa
          for interest in taxon.interests
            if interest.state
              recipients.push(interest.user)
            end
          end
        end

        # Send to everyone (except the person who created the naming!)
        for recipient in recipients.uniq - [sender]
          if recipient.created_here
            QueuedEmail::NameProposal.create_email(sender, recipient, obs, self)
          end
        end
      end
    end
  end

  # Log destruction of Naming and recalculate Observation's consensus after
  # destroy.  (If you're about to destroy the observation, too, then be sure to
  # clear naming.observation -- otherwise it will recalculate the consensus for
  # each deleted naming, and send a bunch of bogus emails.)
  def log_destruction
    if (user = User.current) &&
       (obs = observation)
      obs.log(:log_naming_destroyed, :name => self.format_name)
      obs.calc_consensus
    end
  end

  ##############################################################################
  #
  #  :section: Voting
  #
  ##############################################################################

  # Straight sum of vote values.
  # (Just used by functional tests right now.)
  def vote_sum
    sum = 0.0
    for v in votes
      sum += v.value
    end
    return sum
  end

  # Convert vote_cache to a percentage.
  def vote_percent
    Vote.percent(vote_cache)
  end

  # Has a given User voted for this naming?
  def user_voted?(user)
    !!users_vote(user)
  end

  # Retrieve a given User's vote for this naming.
  def users_vote(user)
    result = nil
    for v in votes
      if (v.user_id == user.id)
        result = v
        break
      end
    end
    return result
  end

  # Is this Naming the given User's favorite Naming for this Observation?
  def is_users_favorite?(user)
    result = false
    for v in votes
      if (v.user_id == user.id) and
         (v.favorite)
        result = true
      end
    end
    return result
  end

  # Has anyone voted (positively) on this?  We don't want people changing
  # the name for namings that the community has voted on.  Returns true if no
  # one has.
  def editable?
    result = true
    for v in votes
      if (v.user_id != user_id) and
         (v.value > 0)
        result = false
        break
      end
    end
    return result
  end

  # Has anyone given this their strongest (positive) vote?  We don't want
  # people destroying namings that someone else likes best.  Returns true if no
  # one has.
  def deletable?
    result = true
    for v in votes
      if (v.user_id != user_id) and
         (v.value > 0) and
         (v.favorite)
        result = false
        break
      end
    end
    return result
  end

  # Create a table the number of User's who cast each level of Vote.
  # (This refreshes the vote_cache while it's at it.)
  #
  #   table = naming.calc_vote_table
  #   for key, record in table
  #     str    = key.l
  #     num    = record[:num]    # Number of users who voted near this level.
  #     weight = record[:wgt]    # Sum of users' weights.
  #     value  = record[:value]  # Value of this level of vote (arbitrary scale).
  #     users  = record[:users]  # List of users who voted near this level.
  #   end
  #
  def calc_vote_table

    # Initialize table.
    table = {}
    for str, val in Vote.agreement_menu
      table[str] = {
        :num   => 0,
        :wgt   => 0.0,
        :value => val,
        :users => [],
      }
    end

    # Gather votes, doing a weighted sum in the process.
    tot_sum = 0
    tot_wgt = 0
    for v in self.votes
      str = v.agreement
      wgt = v.user_weight
      table[str][:wgt] += wgt
      table[str][:num] += 1
      tot_sum += v.value * wgt
      tot_wgt += wgt
    end
    val = tot_sum.to_f / (tot_wgt + 1.0)

    # Update vote_cache if it's wrong.
    if self.vote_cache != val
      self.vote_cache = val
      self.save
    end

    return table
  end

  ##############################################################################
  #
  #  :section: Reasons
  #
  ##############################################################################

  # Array of all reason "types", in the order they should be presented in UI.
  ALL_REASONS = [1, 2, 3, 4]

  # These reasons will be used by default (with empty notes) if no reasons given.
  DEFAULT_REASONS = [1]

  # Localization tags for reason labels.
  REASON_LABELS = [
    :naming_reason_label_1,  # "Recognized by sight"
    :naming_reason_label_2,  # "Used references"
    :naming_reason_label_3,  # "Based on microscopical features"
    :naming_reason_label_4,  # "Based on chemical features"
  ]

  # Return reasons as Array of Reason instances.  Changes to these instances
  # will make appropriate changes to the Naming. 
  def get_reasons
    self.reasons ||= {}
    ALL_REASONS.map do |num|
      Reason.new(reasons, num)
    end
  end

  # Return reasons as Hash of Reason instances.  Changes to these instances
  # will make appropriate changes to the Naming. 
  def get_reasons_hash
    result = {}
    for reason in get_reasons
      result[reason.num] = reason
    end
    return result
  end

  # Update reasons given Hash of notes values.
  def set_reasons(hash)
    for reason in get_reasons
      if hash.has_key?(reason.num)
        reason.notes = hash[reason.num].to_s
      else
        reason.delete
      end
    end
  end

  # Callback used on +before_save+ to enforce certain minimum reasons are used.
  def enforce_default_reasons
    self.reasons ||= {}
    if reasons.keys.empty?
      for num in DEFAULT_REASONS
        reasons[num] = ''
      end
    end

    # Might as well make it nil if empty.
    self.reasons = nil if reasons == {}
    return true
  end

  # = Wrapper on Naming reasons.
  #
  # Each reason in a Naming instance is wrapped in one of these objects.  It
  # facilitates access to those reasons' information, and it allows callers to
  # make changes to the Naming safely.
  #
  # == Attributes
  # num::           Type of reason (Fixnum from 1 to N).
  # notes::         Notes associated with reason (String), or +nil+ if not used.
  #                 *NOTE*: This is writable; changes will be saved with Naming.
  #
  # == Class Methods
  #
  # all_reasons::   Array of all reason types, in display order.
  #
  # == Instance Methods
  #
  # label::         Localization label.
  # order::         Index of this reason in sorted list of reasons.
  # default?::      Will this be set by default if no reasons given?
  # used?::         Is this reason being used by the Naming?
  # delete::        Remove this reason from the Naming.
  #
  class Reason
    attr_accessor :num

    # Return an Array of all reason types, in order they should be displayed.
    def self.all_reasons
      ALL_REASONS
    end

    # Initialize Reason.
    def initialize(reasons, num)
      @reasons = reasons
      @num     = num
    end

    # Get localization string for this reason.  For example:
    #   reason.label.l  -->  "Recognized by sight"
    def label
      REASON_LABELS[@num-1]
    end

    # Return order for sorting:
    #   reasons.sort_by(&:order)
    def order
      @num
    end

    # Is this Reason to be set by default if none given by user?
    def default?
      DEFAULT_REASONS.include?(@num)
    end

    # Is this Reason being used by the parent Naming?
    def used?
      @reasons.has_key?(@num)
    end

    # Get notes, or +nil+ if Reason not used.
    def notes
      @reasons[@num]
    end

    # Set notes, and mark this Reason as "used".
    def notes=(val)
      @reasons[@num] = val.to_s
    end

    # Mark this Reason as "unused".
    def delete
      @reasons.delete(@num)
    end
  end

################################################################################

protected

  def validate # :nodoc:
    if !self.observation
      errors.add(:observation, :validate_naming_observation_missing.t)
    end
    if !self.name
      errors.add(:name, :validate_naming_name_missing.t)
    end
    if !self.user && !User.current
      errors.add(:user, :validate_naming_user_missing.t)
    end
  end
end

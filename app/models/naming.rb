# frozen_string_literal: true

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
#  created_at::             Date/time it was created.
#  updated_at::             Date/time it was last updated.
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
#  change_vote::            Call Observation#change_vote.
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
  has_many :votes, dependent: :destroy

  serialize :reasons

  before_save :did_name_change?
  before_save :enforce_default_reasons
  after_save :create_emails
  after_destroy :log_destruction

  # Override the default show_controller
  def self.show_controller
    "/observer"
  end

  def self.construct(args, observation)
    now = Time.zone.now
    naming = Naming.new(args)
    naming.created_at = now
    naming.updated_at = now
    naming.user = @user
    naming.observation = observation
    naming
  end

  def self.from_params(params)
    if params[:id].blank?
      observation = Observation.find(params[:observation_id])
      observation.consensus_naming
    else
      find(params[:id].to_s)
    end
  end

  # Update naming and log changes.
  def update_object(new_name, log)
    self.name = new_name
    save
    observation.log(:log_naming_updated,
                    name: format_name, touch: log)
    true
  end

  # Need to know if JS was on because it changes how we deal with unchecked
  # reasons that have notes: if JS is off these are considered valid, if JS
  # was on the notes are hidden when the box is unchecked thus it is invalid.
  def create_reasons(args, was_js_on)
    args ||= {}
    get_reasons.each do |reason|
      num = reason.num
      if (x = args[num.to_s])
        check = x[:check]
        notes = x[:notes]
        if (check == "1") ||
           (!was_js_on && notes.present?)
          reason.notes = notes
        else
          reason.delete
        end
      else
        reason.delete
      end
    end
  end

  # Return name in plain text.
  def text_name
    name ? name.real_search_name : ""
  end

  # Return name in plain text (with id tacked on to make unique).
  def unique_text_name
    text_name + " (#{id || "?"})"
  end

  # Return name in Textile format.
  def format_name
    name ? name.observation_name : ""
  end

  def display_name_brief_authors
    name ? name.display_name_brief_authors : ""
  end

  # Return name in Textile format (with id tacked on to make unique).
  def unique_format_name
    format_name + " (#{id || "?"})"
  end

  ##############################################################################
  #
  #  :section: Callbacks
  #
  ##############################################################################

  # Detect name changes in namings
  def did_name_change?
    @name_changed = name_id_changed?
    true
  end

  # Send email notifications after creating or changing the Name.
  def create_emails
    if @name_changed
      @name_changed = false

      # Send email to people interested in this name.
      @initial_name_id = name_id
      taxa = name.approved_name.all_parents
      taxa.push(name)
      taxa.push(Name.find_by_text_name("Lichen")) if name.is_lichen?
      done_user = {}
      flavor = Notification.flavors[:name]
      taxa.each do |taxon|
        Notification.where(flavor: flavor, obj_id: taxon.id).find_each do |n|
          next unless (n.user != user) && !done_user[n.user_id] &&
                      (!n.require_specimen || observation.specimen)

          QueuedEmail::NameTracking.create_email(n, self)
          done_user[n.user_id] = true
        end
      end

      # Send email to people interested in this observation.
      if obs = observation
        owner  = obs.user
        sender = user
        recipients = []

        # Send notification to owner if they want.
        recipients.push(owner) if owner&.email_observations_naming

        # Send to people who have registered interest in this observation.
        # Also remove everyone who has explicitly said they are NOT interested.
        for interest in obs.interests
          if interest.state
            recipients.push(interest.user)
          else
            recipients.delete(interest.user)
          end
        end

        # Also send to people who registered positive interest in this name.
        # (Don't want *disinterest* in name overriding
        # interest in the observation, say.)
        for taxon in taxa
          for interest in taxon.interests
            recipients.push(interest.user) if interest.state
          end
        end

        # Send to everyone (except the person who created the naming!)
        for recipient in recipients.uniq - [sender]
          QueuedEmail::NameProposal.create_email(sender, recipient, obs, self)
        end
      end
    end
  end

  # Log destruction of Naming and recalculate Observation's consensus after
  # destroy.  (If you're about to destroy the observation, too, then be sure to
  # clear naming.observation -- otherwise it will recalculate the consensus for
  # each deleted naming, and send a bunch of bogus emails.)
  def log_destruction
    if User.current &&
       (obs = observation)
      obs.log(:log_naming_destroyed, name: format_name)
      obs.calc_consensus
    end
  end

  def init_reasons(args = nil)
    result = {}
    get_reasons.each do |reason|
      num = reason.num

      # Use naming's reasons by default.
      result[num] = reason

      # Override with values in params.
      next unless args

      if (x = args[num.to_s])
        check = x[:check]
        notes = x[:notes]
        # Reason is "used" if checked or notes non-empty.
        if (check == "1") ||
           notes.present?
          reason.notes = notes
        else
          reason.delete
        end
      else
        reason.delete
      end
    end
    result
  end

  # It is rare, but a single user can end up with multiple votes, for example,
  # if two names are merged and a user had voted for both names.
  def owners_vote
    Vote.where(naming_id: id, user_id: user_id).order("value desc").first
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
    sum
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
    votes.each { |v| return v if v.user_id == user.id }
    nil
  end

  # Is this Naming the given User's favorite Naming for this Observation?
  def is_users_favorite?(user)
    votes.each { |v| return true if (v.user_id == user.id) && v.favorite }
    false
  end

  # Change User's Vote on this Naming.  (Uses Observation#change_vote.)
  def change_vote(value, user = User.current)
    observation.change_vote(self, value, user)
  end

  def update_name(new_name, user, reason, was_js_on)
    clean_votes(new_name, user)
    create_reasons(reason, was_js_on)
    update_object(new_name, changed?)
  end

  def clean_votes(new_name, user)
    if new_name != name
      votes.each do |vote|
        vote.destroy if vote.user_id != user.id
      end
    end
  end

  # Has anyone voted (positively) on this?  We don't want people changing
  # the name for namings that the community has voted on.  Returns true if no
  # one has.
  def editable?
    votes.each do |v|
      return false if (v.user_id != user_id) && v.value.positive?
    end
    true
  end

  # Has anyone given this their strongest (positive) vote?  We don't want
  # people destroying namings that someone else likes best.  Returns true if no
  # one has.
  def deletable?
    votes.each do |v|
      return false if (v.user_id != user_id) && v.value.positive? && v.favorite
    end
    true
  end

  # Create a table the number of User's who cast each level of Vote.
  # (This refreshes the vote_cache while it's at it.)
  #
  #   table = naming.calc_vote_table
  #   for key, record in table
  #     str    = key.l
  #     num    = record[:num]    # Number of users who voted near this level.
  #     weight = record[:wgt]    # Sum of users' weights.
  #     value  = record[:value]  # Value of this level of vote (arbitrary scale)
  #     votes  = record[:votes]  # List of actual votes.
  #   end
  #
  def calc_vote_table
    # Initialize table.
    table = {}
    for str, val in Vote.opinion_menu
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
    for v in votes
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
    if vote_cache != val
      self.vote_cache = val
      save
    end

    table
  end

  ##############################################################################
  #
  #  :section: Reasons
  #
  ##############################################################################

  # Array of all reason "types", in the order they should be presented in UI.
  ALL_REASONS = [1, 2, 3, 4].freeze

  # These reasons will be used by default (with empty notes) if no reasons given
  DEFAULT_REASONS = [1].freeze

  # Localization tags for reason labels.
  REASON_LABELS = [
    :naming_reason_label_1,  # "Recognized by sight"
    :naming_reason_label_2,  # "Used references"
    :naming_reason_label_3,  # "Based on microscopical features"
    :naming_reason_label_4   # "Based on chemical features"
  ].freeze

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
    result
  end

  # Update reasons given Hash of notes values.
  def set_reasons(hash)
    for reason in get_reasons
      if hash.key?(reason.num)
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
        reasons[num] = ""
      end
    end

    # Might as well make it nil if empty.
    self.reasons = nil if reasons == {}
    true
  end

  # = Wrapper on Naming reasons.
  #
  # Each reason in a Naming instance is wrapped in one of these objects.  It
  # facilitates access to those reasons' information, and it allows callers to
  # make changes to the Naming safely.
  #
  # == Attributes
  # num::           Type of reason (Integer from 1 to N).
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
      REASON_LABELS[@num - 1]
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
      @reasons.key?(@num)
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

  ##############################################################################

  protected

  validate :check_requirements
  def check_requirements # :nodoc:
    unless observation
      errors.add(:observation, :validate_naming_observation_missing.t)
    end
    errors.add(:name, :validate_naming_name_missing.t) unless name
    errors.add(:user, :validate_naming_user_missing.t) if !user && !User.current
  end
end

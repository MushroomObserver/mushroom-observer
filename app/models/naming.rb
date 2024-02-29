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
#  ==== Votes
#  votes::                  List of Vote's attached to this Naming.
#  vote_sum::               Straight sum of Vote's for this Naming.
#  vote_percent::           Convert cached Vote score to a percentage.
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
  after_destroy :log_destruction
  after_save :create_emails

  # Override the default show_controller
  def self.show_controller
    "/observations"
  end

  # Override the default show_url
  # (this is a hack, here, to get the right URL)
  def self.show_url
    false
  end

  def self.construct(args, observation)
    now = Time.zone.now
    naming = Naming.new(args)
    naming.created_at = now
    naming.updated_at = now
    naming.user = User.current
    naming.observation = observation
    naming
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
    reasons_array.each do |reason|
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
  def create_emails # rubocop:disable Metrics/MethodLength
    return unless @name_changed

    @name_changed = false

    # Send email to people interested in this name.
    @initial_name_id = name_id
    taxa = name.approved_name.all_parents
    taxa.push(name)
    taxa.push(Name.find_by(text_name: "Lichen")) if name.is_lichen?
    # taxa = name.approved_name.all_parents(
    #   includes: [:interests], add_self: true, add_lichen: name.is_lichen?
    # )

    done_user = {}
    taxa.each do |taxon|
      NameTracker.where(name: taxon).includes(:user).find_each do |n|
        next unless (n.user_id != user.id) && !done_user[n.user_id] &&
                    (!n.require_specimen || observation.specimen)
        next if n.user.no_emails

        QueuedEmail::NameTracking.create_email(n, self)
        done_user[n.user_id] = true
      end
    end

    # Send email to people interested in this observation.
    return unless (obs = observation)

    owner  = obs.user
    sender = user
    recipients = []

    # Send notification to owner if they want.
    recipients.push(owner) if owner&.email_observations_naming

    # Send to people who have registered interest in this observation.
    # Also remove everyone who has explicitly said they are NOT interested.
    obs.interests.each do |interest|
      if interest.state
        recipients.push(interest.user)
      else
        recipients.delete(interest.user)
      end
    end

    # Also send to people who registered positive interest in this name.
    # (Don't want *disinterest* in name overriding
    # interest in the observation, say.)
    taxa.each do |taxon|
      taxon.interests.each do |interest|
        recipients.push(interest.user) if interest.state
      end
    end

    # Remove users who have opted out of all emails.
    recipients.reject!(&:no_emails)

    # Send to everyone (except the person who created the naming!)
    (recipients.uniq - [sender]).each do |recipient|
      QueuedEmail::NameProposal.create_email(sender, recipient, obs, self)
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
      obs = Observation.naming_includes.find(obs.id) # get a fresh eager-load
      consensus = Observation::NamingConsensus.new(obs)
      consensus.calc_consensus
    end
  end

  ##############################################################################
  #
  #  :section: Votes
  #
  ##############################################################################

  # Straight sum of vote values.
  # (Just used by functional tests right now.)
  def vote_sum
    sum = 0.0
    votes.each do |v|
      sum += v.value
    end
    sum
  end

  # Convert vote_cache to a percentage.
  def vote_percent
    Vote.percent(vote_cache)
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
  def reasons_array
    self.reasons ||= {}
    ALL_REASONS.map do |num|
      Reason.new(reasons, num)
    end
  end

  # Return reasons as Hash of Reason instances.  Changes to these instances
  # will make appropriate changes to the Naming.
  def reasons_hash
    result = {}
    reasons_array.each do |reason|
      result[reason.num] = reason
    end
    result
  end

  def init_reasons(args = nil)
    result = {}
    reasons_array.each do |reason|
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

  # Update reasons given Hash of notes values.
  def update_reasons(hash)
    reasons_array.each do |reason|
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
      DEFAULT_REASONS.each do |num|
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
    def initialize(reason_structure, num)
      @reason_structure = reason_structure
      @num              = num
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
      @reason_structure.key?(@num)
    end

    # Get notes, or +nil+ if Reason not used.
    def notes
      @reason_structure[@num]
    end

    # Set notes, and mark this Reason as "used".
    def notes=(val)
      @reason_structure[@num] = val.to_s
    end

    # Mark this Reason as "unused".
    def delete
      @reason_structure.delete(@num)
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
    errors.add(:user, :validate_naming_user_missing.t) if !user_id &&
                                                          !User.current
  end
end

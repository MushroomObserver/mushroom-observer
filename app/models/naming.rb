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
#
#  == Class methods
#
#  None.
#
#  == Instance methods
#
#  naming_reasons::         List of NamingReasons attached to this object.
#  editable?::              Has anyone voted (positively) on this naming?
#  deletable?::             Has anyone made this Naming their favorite?
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
#  calc_vote_table::        (Used by show_votes.rhtml.)
#  change_vote::            Change a User's Vote for this Naming.
#  is_owners_favorite?::    Is this (one of) the owner's favorite(s)?
#  is_users_favorite?::     Is this (one of) a given User's favorite(s)?
#  is_consensus?::          Is this the community consensus?
#
#  == Callbacks
#
#  did_name_change?::       Check if name changed before saving.
#  create_emails::          Notify users of changes after saving.
#  log_destruction::        Log destruction after destroying it.
#
################################################################################

class Naming < AbstractModel
  belongs_to :observation
  belongs_to :name
  belongs_to :user
  has_many   :naming_reasons, :dependent => :destroy
  has_many   :votes,          :dependent => :destroy

  before_save   :did_name_change?
  after_save    :create_emails
  after_destroy :log_destruction

  # Detect name changes in namings
  def did_name_change?
    @name_changed = self.name_id_changed?
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
            QueuedEmail::Naming.create_email(n, self)
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

  # Straight sum of vote values.
  # (Just used by functional tests right now.)
  def vote_sum
    sum = 0
    for v in self.votes
      sum += v.value
    end
    return sum
  end

  # Convert vote_cache to a percentage.
  def vote_percent
    v = self.vote_cache
    return 0.0 if v.to_s == ''
    return v * 100 / 3
  end

  # Has a given User voted for this naming?
  def user_voted?(user)
    result = false
    if user
      result = votes.find(:first, :conditions => ['user_id = ?', user.id])
    end
    return result ? true : false
  end

  # Retrieve a given User's vote for this naming.
  def users_vote(user)
    result = nil
    if user
      result = votes.find(:first, :conditions => ['user_id = ?', user.id])
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
        :wgt   => 0,
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

  # Change User's Vote for this naming.  Automatically recalculates the
  # consensus for the Observation in question if anything is changed.  Returns
  # true if something was changed. 

  def change_vote(user, value)
    result = false

    now  = Time.now
    vdel = Vote.delete_vote
    v80  = Vote.next_best_vote
    vote = votes.find(:first, :conditions => ['user_id = ?', user.id])

    # Negative value means destroy vote.
    if value == vdel
      if vote
        vote.destroy
        result = true
      end

    # Otherwise create new vote or modify existing vote.
    elsif !vote || vote.value != value
      result = true

      # First downgrade any existing 100% votes (if casting a 100% vote).
      if value > v80
        for n in observation.namings
          v = n.users_vote(user)
          if v && v.value > v80
            v.modified = now
            v.value    = v80
            v.save
            Transaction.put_vote(
              :id        => v,
              :set_value => v80
            )
          end
        end
      end

      # Create vote if none exists.
      if !vote
        vote = Vote.new
        vote.created     = now
        vote.modified    = now
        vote.user        = user
        vote.observation = observation
        vote.naming      = self
        vote.value       = value
        vote.save
        Transaction.post_vote(
          :id     => vote,
          :naming => self,
          :value  => value
        )

      # Change vote if it exists.
      else
        vote.modified = now
        vote.value    = value
        vote.save
        Transaction.put_vote(
          :id        => vote,
          :set_value => value
        )
      end
    end

    # Update consensus if anything changed.
    observation.calc_consensus(user) if result

    return result
  end

  # Has anyone voted (positively) on this?  We don't want people changing
  # the name for namings that the community has voted on.  Returns true if no
  # one has.
  def editable?
    for v in votes
      return false if v.user_id != user_id and v.value > 0
    end
    return true
  end

  # Has anyone given this their strongest (positive) vote?  We don't want
  # people destroying namings that someone else likes best.  Returns true if no
  # one has. 
  def deletable?
    result = true
    for v in votes
      if v.user_id != user_id and v.value > 0
        if is_users_favorite?(v.user)
          result = false
          break
        end
      end
    end
    return result
  end

  # Returns true if this naming has received the highest positive vote
  # from the owner of the corresponding observation.  Note, multiple namings
  # can return true for a given observation.
  def is_owners_favorite?
    is_users_favorite?(observation.user)
  end

  # Returns true if this naming has received the highest positive vote
  # from the given user (among namings for the corresponding observation).
  # Note, multiple namings can return true for a given user and observation.
  def is_users_favorite?(user)
    result = false
    if obs = observation
      max = 0
      votes = Vote.find_all_by_observation_id_and_user_id(obs.id, user.id)
      for vote in votes
        max = vote.value if vote.value > 0 && vote.value > max
      end
      if max > 0
        for vote in votes
          if vote.naming == self && vote.value == max
            result = true
            break
          end
        end
      end
    end
    return result
  end

  # If the community consensus clearly derives from a single Naming, then this
  # will return true for that Naming.  It returns false for everything else.
  # See observation#consensus_naming for a more accurate method that takes
  # synonymy into account.
  def is_consensus?
    observation.name == name
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

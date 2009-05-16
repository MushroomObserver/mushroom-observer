#
#  Model used to associate a single proposed Name with an Observation.  An
#  Observation generally has one or more Naming's, but it can have none,
#  meaning that it is unidentified.  It's basic properties are:
#
#  1. has a Name
#  2. owned by a User
#  3. belongs to an Observation
#  4. can have many Vote's (note that the consensus vote is cached here)
#  5. has zero or more NamingReason's (in place of notes)
#
#  Name formating:
#    text_name               Plain text.  (uses name.search_name)
#    format_name             Textilized.  (uses name.observation_name)
#    unique_text_name        Same as above, with id added to make unique.
#    unique_format_name
#
#  Voting and preferences:
#    vote_sum                Straight sum of votes for this naming.
#    vote_percent            Convert cached vote score to a percentage.
#    user_voted?(user)       Has a given user voted on this naming?
#    users_vote(user)        Get a given user's vote on this naming.
#    calc_vote_table         Used by show_votes.rhtml
#    change_vote(user, val)  Change a user's vote for this naming.
#    is_owners_favorite?     Is this (one of) the owner's favorite(s)?
#    is_users_favorite?(user) Is this (one of) the user's favorite(s)?
#    is_consensus?           Is this the community consensus?
#    editable?               Has anyone voted (positively) on this naming?
#    deletable?              Has anyone made this naming their favorite?
#
################################################################################

class Naming < ActiveRecord::Base
  belongs_to :observation
  belongs_to :name
  belongs_to :user
  has_many   :naming_reasons,    :dependent => :destroy
  has_many   :votes,             :dependent => :destroy

  # Creating or changing a naming can trigger all sorts of emails.
  def create_emails(current_name_id=nil)
    if self.name_id != current_name_id

      # Send email to people interested in this name.
      @initial_name_id = self.name_id
      taxa = self.name.ancestors
      taxa.push(self.name)
      for taxon in taxa
        for n in Notification.find_all_by_flavor_and_obj_id(:name, taxon.id)
          NamingEmail.create_email(n, self)
        end
      end

      # Send email to people interested in this observation.
      if observation = self.observation
        owner  = observation.user
        sender = self.user
        recipients = []

        # Send notification to owner if they want.
        recipients.push(owner) if owner && owner.name_proposal_email

        # Send to people who have registered interest.
        # Also remove everyone who has explicitly said they are NOT interested.
        for interest in Interest.find_all_by_object(observation)
          if interest.state
            recipients.push(interest.user)
          else
            recipients.delete(interest.user)
          end
        end

        # Send to everyone (except the person who created the naming!)
        for recipient in recipients.uniq
          if recipient && recipient != sender
            NameProposalEmail.create_email(sender, recipient, observation, self)
          end
        end
      end
    end
  end

  def after_create
    super
    create_emails()
  end

  # Detect name changes in namings
  def after_initialize
    @initial_name_id = self.name_id
  end

  def after_update
    create_emails(@initial_name_id)
  end

  # Various name formats.
  def text_name
    self.name.search_name
  end

  def unique_text_name
    str = self.name.search_name
    "%s (%s)" % [str, self.id]
  end

  def format_name
    self.name.observation_name
  end

  def unique_format_name
    str = self.name.observation_name
    "%s (%s)" % [str, self.id]
  end

  # Just used by functional tests right now.
  def vote_sum
    sum = 0
    for v in self.votes
      sum += v.value
    end
    return sum
  end

  # Just convert vote_cache to a percentage.
  def vote_percent
    v = self.vote_cache
    return 0.0 if v.nil? || v == ""
    return v * 100 / 3
  end

  # Has a given user voted for this naming?
  def user_voted?(user)
    return false if !user || !user.verified
    vote = self.votes.find(:first,
      :conditions => ['user_id = ?', user.id])
    return vote ? true : false
  end

  # Retrieve a given user's vote for this naming.
  def users_vote(user)
    return false if !user || !user.verified
    self.votes.find(:first,
      :conditions => ['user_id = ?', user.id])
  end

  # Create the structure used by show_votes view:
  # Just a table of number of users who cast each level of vote.
  def calc_vote_table
    table = Hash.new
    for str, val in Vote.agreement_menu
      table[str] = {
        :num   => 0,
        :wgt   => 0,
        :value => val,
        :users => [],
      }
    end
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
    if self.vote_cache != val
      self.vote_cache = val
      self.save
    end
    return table
  end

  # Change user's vote for this naming.  Automatically recalculates the
  # consensus for the observation in question if anything is changed.
  # Returns: true if something was changed.
  def change_vote(user, value)
    vdel = Vote.delete_vote
    v100 = Vote.maximum_vote
    v80  = Vote.next_best_vote
    vote = self.votes.find(:first,
      :conditions => ['user_id = ?', user.id])
    # Negative value means destroy vote.
    if value == vdel
      return false if !vote
      vote.destroy
    # Otherwise create new vote or modify existing vote.
    else
      return false if vote && vote.value == value
      now = Time.now
      # First downgrade any existing 100% votes (if casting a 100% vote).
      if value == v100
        for n in self.observation.namings
          v = n.users_vote(user)
          if v && v.value == v100
            v.modified = now
            v.value    = v80
            v.save
          end
        end
      end
      # Now create/change vote.
      if !vote
        vote = Vote.new
        vote.created     = now
        vote.user        = user
        vote.naming      = self
        vote.observation = self.observation
      end
      vote.modified = now
      vote.value    = value
      vote.save
    end
    # Update consensus.
    self.observation.calc_consensus(user)
    return true
  end

  # Has anyone voted (positively) on this?  We don't want people changing
  # the name for namings that the community has voted on.
  # Returns true if no one has.
  def editable?
    for v in self.votes
      return false if v.user_id != self.user_id and v.value > 0
    end
    return true
  end

  # Has anyone given this their strongest (positive) vote?  We don't want people
  # destroying namings that someone else likes best.
  # Returns true if no one has.
  def deletable?
    for v in self.votes
      if v.user_id != self.user_id and v.value > 0
        return false if self.is_users_favorite?(v.user)
      end
    end
    return true
  end

  # Returns true if this naming has received the highest positive vote
  # from the owner of the corresponding observation.  Note, multiple namings
  # can return true for a given observation.
  def is_owners_favorite?
    self.is_users_favorite?(self.observation.user)
  end

  # Returns true if this naming has received the highest positive vote
  # from the given user (among namings for the corresponding observation).
  # Note, multiple namings can return true for a given user and observation.
  def is_users_favorite?(user)
    obs = self.observation
    if obs
      # was
      # votes = user.votes.select {|v| v.naming.observation == obs}
      votes = Vote.find_all_by_observation_id_and_user_id(obs.id, user.id)
      max = 0
      for vote in votes
        max = vote.value if vote.value > 0 && vote.value > max
      end
      if max > 0
        for vote in votes
          return true if vote.naming == self && vote.value == max
        end
      end
    end
    return false
  end

  # If the community consensus clearly derives from a single naming, then this
  # will return true for that naming.  It returns false for everything else.
  # See observation.consensus_naming for a more accurate method that takes
  # synonymy into account.
  def is_consensus?
    self.observation.name == self.name
  end

  protected

  def validate # :nodoc:
    if !self.observation
      errors.add(:observation, :validate_naming_observation_missing.t)
    end
    if !self.name
      errors.add(:name, :validate_naming_name_missing.t)
    end
    if !self.user
      errors.add(:user, :validate_naming_user_missing.t)
    end
  end
end

require 'active_record_extensions'

################################################################################
#
#  Model describing an observation.  Conceptually very simple, but since it is
#  at the nexus of many other objects, it gets a bit complex.  Properties:
#
#  1. has a date (when observation was made, not created)
#  2. has a location (called "where" until a Location is created, then "location")
#  3. has notes, and a few flags (e.g. voucher?)
#  4. can have one or more Image's (including one "thumb_image")
#  5. can have one or more Naming's
#  6. has a consensus Name and Vote (cached)
#  7. owned by a User
#  8. can belong to one or more SpeciesList's
#  9. has an RssLog
#
#  Voting is still in a state of flux.  At the moment users create Naming's and
#  people Vote on them.  We combine the Vote's for each Naming, cache the Vote
#  for each Naming in the Naming.  However no Naming necessarily wins --
#  instead Vote's are tallied for each Synonym (see calc_consensus) for full
#  details).  Thus the accepted Name of the winning Synonym is cached in the
#  Observation along with its winning Vote score.
#
#  RSS log:
#    log(msg, touch)      Add message to log (creating log if necessary).
#    orphan_log(entry)    Same as log() except observation is about to go away.
#
#  Naming stuff:
#    name                 Conensus Name instance. (never nil)
#    text_name            Plain text.
#    format_name          Textilized.
#    unique_text_name     Same as above, with id added to make unique.
#    unique_format_name
#
#    calc_consensus          Calculate and cache the consensus naming/name.
#    name_been_proposed?(n)  Has someone proposed this name already?
#    consensus_naming        Guess which naming is responsible for consensus.
#    O.refresh_vote_cache    Refresh cache across all observations.
#
#  Image stuff:
#    add_image(img)         Add img to obv.
#    add_image_by_id(id)    Add img to obv.
#    remove_image_by_id(id) Remove img from obv.
#
#  Location/Where ambiguity:
#    place_name             Get location name or where, whichever exists.
#    place_name=            Set where if cannot find location by that name.
#
#  Callbacks:
#    add_spl_callback(o)    Updates SiteData when obs is added to species list.
#    remove_spl_callback(o) Updates SiteData when obs is removed from species list.
#
#  Validates:
#    requires presence of user and location
#
################################################################################

class Observation < ActiveRecord::Base
  has_and_belongs_to_many :images, :order => "id"
  has_and_belongs_to_many :species_lists,
    :after_add => :add_spl_callback, :before_remove => :remove_spl_callback
  belongs_to :thumb_image, :class_name => "Image", :foreign_key => "thumb_image_id"
  has_many :comments, :dependent => :destroy, :as => :object
  has_many :namings,  :dependent => :destroy
  has_one :rss_log
  belongs_to :name      # (used to cache consensus name)
  belongs_to :location
  belongs_to :user

  before_destroy :save_id_before_destroy
  after_destroy  :notify_interested_users_after_destroy
  after_save     :notify_interested_users_after_change

  def add_spl_callback(o) # :nodoc:
    SiteData.update_contribution(:create, self, :species_list_entries, 1)
  end

  def remove_spl_callback(o) # :nodoc:
    SiteData.update_contribution(:destroy, self, :species_list_entries, 1)
  end

  # Log change to the observation.  Creates new rss_log if necessary.
  def log(*args)
    self.rss_log ||= RssLog.new
    self.rss_log.add_with_date(*args)
  end

  # Log change to the observation that's about to be deleted.  Creates new
  # rss_log if necessary.
  def orphan_log(*args)
    self.rss_log ||= RssLog.new
    self.rss_log.orphan(self.format_name, *args)
  end

  # Change modified time to now.
  def touch
    @modified = Time.new
  end

  ########################################

  # Return the review status based on the votes on the consensus name by current reviewers.
  # Possible return values:
  #   :unreviewed - No reviewers have voted for the consensus
  #   :inaccurate - Some reviewer doubts the consensus (vote.value < 0)
  #   :vetted - All reviewers that have voted on the current consensus fully support this name
  #   :unvetted - Some reviewer is not completely confident in this naming (vote.value < 3)
  # It probably makes sense to cache this result at some point.
  def review_status
    naming = Naming.find_by_name_id_and_observation_id(self.name_id, self.id)
    votes = []
    if naming
      votes = Vote.find_all_by_naming_id(naming.id)
    end
    status = :unreviewed
    for v in votes
      if v.user.in_group('reviewers')
        value = v.value
        if value < 0
          status = :inaccurate
          break
        elsif status != :inaccurate
          if value < 3
            status = :unvetted
          elsif status == :unreviewed
            status = :vetted
          end
        end
      end
    end
    status
  end

  # Get the community consensus on what the name should be.  It just adds up
  # the votes weighted by user contribution, and picks the winner.  To break a
  # tie it takes the one with the most votes (again weighted by contribution).
  # Failing that it takes the oldest one.  Note, it lumps all synonyms together
  # when deciding the winning "taxon", using votes for the separate synonyms
  # only when there are multiple "accepted" names for the winning taxon.
  #
  # Returns Naming instance or nil.  Refreshes vote_cache as a side-effect.
  def calc_consensus(current_user=nil, debug=false)
    self.reload
result = "" if debug

    # Gather votes for names and synonyms.  Note that this is trickier than one
    # would expect since it is possible to propose several synonyms for a
    # single observation, and even worse perhaps, one can even propose the very
    # same name multiple times.  Thus a user can potentially vote for a given
    # *name* (not naming) multiple times.  Likewise, of course, for synonyms.
    # I choose the strongest vote in such cases.
    name_votes  = {}  # Records the strongest vote for a given name for a given user.
    taxon_votes = {}  # Records the strongest vote for any names in a group of synonyms for a given user.
    name_ages   = {}  # Records the oldest date that a name was proposed.
    taxon_ages  = {}  # Records the oldest date that a taxon was proposed.
    user_wgts   = {}  # Caches user rankings.
    for naming in self.namings
      naming_id = naming.id
      name_id = naming.name_id
      name_ages[name_id] = naming.created if !name_ages[name_id] || naming.created < name_ages[name_id]
      sum_val = 0
      sum_wgt = 0
      # Go through all the votes for this naming.  Should be zero or one per
      # user.
      for vote in naming.votes
        user_id = vote.user_id
        val = vote.value
        wgt = user_wgts[user_id]
        if wgt.nil?
          wgt = user_wgts[user_id] = vote.user_weight
        end
        # It may be possible in the future for us to weight some "special"
        # users zero, who knows...  (It can cause a division by zero below if
        # we ignore zero weights.)
        if wgt > 0
          # Calculate score for naming.vote_cache.
          sum_val += val * wgt
          sum_wgt += wgt
          # Record best vote for this user for this name.  This will be used
          # later to determine which name wins in the case of the winning taxon
          # (see below) having multiple accepted names.
          name_votes[name_id] = {} if !name_votes[name_id]
          if !name_votes[name_id][user_id] ||
              name_votes[name_id][user_id][0] < val
            name_votes[name_id][user_id] = [val, wgt]
          end
          # Record best vote for this user for this group of synonyms.  (Since
          # not all taxa have synonyms, I've got to create a "fake" id that
          # uses the synonym id if it exists, else uses the name id, but still
          # keeps them separate.)
          taxon_id = naming.name.synonym ? "s" + naming.name.synonym_id.to_s : "n" + name_id.to_s
          taxon_ages[taxon_id] = naming.created if !taxon_ages[taxon_id] || naming.created < taxon_ages[taxon_id]
          taxon_votes[taxon_id] = {} if !taxon_votes[taxon_id]
result += "raw vote: taxon_id=#{taxon_id}, name_id=#{name_id}, user_id=#{user_id}, val=#{val}<br/>" if debug
          if !taxon_votes[taxon_id][user_id] ||
              taxon_votes[taxon_id][user_id][0] < val
            taxon_votes[taxon_id][user_id] = [val, wgt]
          end
        end
      end
      # Note: this is used by consensus_naming(), not this method.
      value = sum_wgt > 0 ? sum_val.to_f / (sum_wgt + 1.0) : 0.0
      if naming.vote_cache != value
        naming.vote_cache = value
        naming.save
      end
    end

    # Now that we've weeded out potential duplicate votes, we can combine them
    # safely.
    votes = {}
    for taxon_id in taxon_votes.keys
      vote = votes[taxon_id] = [0, 0]
      for user_id in taxon_votes[taxon_id].keys
        user_vote = taxon_votes[taxon_id][user_id]
        val = user_vote[0]
        wgt = user_vote[1]
        vote[0] += val * wgt
        vote[1] += wgt
result += "vote: taxon_id=#{taxon_id}, user_id=#{user_id}, val=#{val}, wgt=#{wgt}<br/>" if debug
      end
    end

    # Now we can determine the winner among the set of synonym-groups.  (Nathan
    # calls these synonym-groups "taxa", because it better uniquely represents
    # the underlying mushroom taxon, while it might have multiple names.)
    best_val = nil
    best_wgt = nil
    best_age = nil
    best_id  = nil
    for taxon_id in votes.keys
      wgt = votes[taxon_id][1]
      val = votes[taxon_id][0].to_f / (wgt + 1.0)
      age = taxon_ages[taxon_id]
result += "#{taxon_id}: val=#{val} wgt=#{wgt} age=#{age}<br/>" if debug
      if best_val.nil? ||
         val > best_val || val == best_val && (
         wgt > best_wgt || wgt == best_wgt && (
         age < best_age
        ))
        best_val = val
        best_wgt = wgt
        best_age = age
        best_id  = taxon_id
      end
    end
result += "best: id=#{best_id}, val=#{best_val}, wgt=#{best_wgt}, age=#{best_age}<br/>" if debug

    # Reverse our kludge that mashed names-without-synonyms and synonym-groups
    # together.  In the end we just want a name.
    if best_id
      match = /^(.)(\d+)/.match(best_id)
      # Synonym id: go through namings and pick first one that belongs to this
      # synonym group.  Any will do for our purposes, because we will convert
      # it to the currently accepted name below.
      if match[1] == "s"
        for naming in self.namings
          if naming.name.synonym_id.to_s == match[2]
            best = naming.name
            break
          end
        end
      else
        best = Name.find(match[2].to_i)
      end
    end
result += "unmash: best=#{best ? best.text_name : "nil"}<br/>" if debug

    # Now deal with synonymy properly.  If there is a single accepted name,
    # great, otherwise we need to somehow disambiguate.
    if best && best.synonym
      names = best.approved_synonyms
      names = best.synonym.names if names.length == 0
      if names.length == 1
        best = names.first
      elsif names.length > 1
result += "Multiple approved synonyms: #{names.map {|x| x.id}.join(', ')}<br>" if debug

        # First combine votes for each name; exactly analagous to what we did
        # with taxa above.
        votes = {}
        for name_id in name_votes.keys
          vote = votes[name_id] = [0, 0]
          for user_id in name_votes[name_id].keys
            user_vote = name_votes[name_id][user_id]
            val = user_vote[0]
            wgt = user_vote[1]
            vote[0] += val * wgt
            vote[1] += wgt
result += "vote: name_id=#{name_id}, user_id=#{user_id}, val=#{val}, wgt=#{wgt}<br/>" if debug
          end
        end

        # Now pick the winner among the ambiguous names.  If none are voted on,
        # just pick the first one (I grow weary of these games).  This latter
        # is all too real of a possibility: users may vigorously debate
        # deprecated names, then at some later date two *new* names are created
        # for the taxon, both are considered "accepted" until the scientific
        # community rules definitively.  Now we have two possible names
        # winning, but no votes on either!  If you have a problem with the one
        # I chose, then vote on the damned thing, already! :)
        best_val2 = nil
        best_wgt2 = nil
        best_age2 = nil
        best_id2  = nil
        for name in names
          name_id = name.id
          vote = votes[name_id]
          if vote
            wgt = vote[1]
            val = vote[0].to_f / (wgt + 1.0)
            age = name_ages[name_id]
result += "#{name_id}: val=#{val} wgt=#{wgt} age=#{age}<br/>" if debug
            if best_val2.nil? ||
               val > best_val2 || val == best_val2 && (
               wgt > best_wgt2 || wgt == best_wgt2 && (
               age < best_age2
              ))
              best_val2 = val
              best_wgt2 = wgt
              best_age2 = age
              best_id2  = name_id
            end
          end
        end
result += "best: id=#{best_id2}, val=#{best_val2}, wgt=#{best_wgt2}, age=#{best_age2}<br/>" if debug
        best = best_id2 ? Name.find(best_id2) : names.first
      end
    end
result += "unsynonymize: best=#{best ? best.text_name : "nil"}<br/>" if debug

    # This should only occur for observations created by
    # species_list.construct_observation(), which doesn't necessarily create
    # any votes associated with its naming.  Therefore this should only ever
    # happen when there is a single naming, so there is nothing arbitray in
    # using first.  (I think it can also happen if zero-weighted users are
    # voting.)
    best = self.namings.first.name if !best && self.namings && self.namings.length > 0
    best = Name.unknown if !best
result += "fallback: best=#{best ? best.text_name : 'nil'}" if debug

    # Make changes permanent.
    old = self.name
    self.name = best
    self.vote_cache = best_val
    self.save

    # Log change if actually is a change.
    if best != old
      if old
        self.log(:log_consensus_changed, { :old => old.observation_name, :new => best.observation_name }, true)
      else
        self.log(:log_consensus_created, { :name => best.observation_name }, true)
      end

      # Change can trigger emails.
      owner  = self.user
      sender = current_user
      recipients = []

      # Tell owner of observation if they want.
      recipients.push(owner) if owner && owner.consensus_change_email

      # Send to people who have registered interest.
      # Also remove everyone who has explicitly said they are NOT interested.
      for interest in Interest.find_all_by_object(self)
        if interest.state
          recipients.push(interest.user)
        else
          recipients.delete(interest.user)
        end
      end

      # Send notification to all except the person who triggered the change.
      for recipient in recipients.uniq
        if recipient && recipient != sender
          ConsensusChangeEmail.create_email(sender, recipient, self, old, best)
        end
      end
    end

return result if debug
  end

  ########################################

  # Name in plain text, never nil.
  def text_name
    self.name.search_name
  end

  # Name in plain text with id to make it unique, never nil.
  def unique_text_name
    str = self.name.search_name
    "%s (%s)" % [str, self.id]
  end

  # Textile-marked-up name, never nil.
  def format_name
    self.name.observation_name
  end

  # Textile-marked-up name with id to make it unique, never nil.
  def unique_format_name
    str = self.name.observation_name
    "%s (%s)" % [str, self.id]
  end

  # Has anyone proposed a given name yet for this observation?
  def name_been_proposed?(name)
    self.namings.select {|n| n.name == name}.length > 0
  end

  # Try to guess which naming is responsible for the consensus.
  def consensus_naming
    result = nil
    matches = self.namings.select {|n| n.name_id == self.name_id}
    if matches == [] && self.name && self.name.synonym
      synonyms = self.name.synonym.names
      matches = self.namings.select {|n| synonyms.include? n.name}
    end
    if matches.length == 1
      result = matches.first
    else
      best_naming = matches.first
      if best_naming
        best_value  = matches.first.vote_cache
        for naming in matches
          if naming.vote_cache > best_value
            best_naming = naming
            best_value  = naming.vote_cache
          end
        end
        result = best_naming
      end
    end
    return result
  end

  ########################################

  # Add image to this observation, making thumbnail if none set already.
  # Saves changes.  Returns nothing.
  def add_image(img)
    img.observations << self
    unless self.thumb_image
      self.thumb_image = img
      self.save
    end
    notify_interested_users(:added_image)
  end

  # Finds image by id then calls add_image().
  # Saves changes.  Returns image instance.
  def add_image_by_id(id)
    result = nil
    if id != 0
      result = Image.find(id)
      if result && !self.images.include?(result)
        self.add_image(result)
      end
    end
    result
  end

  # Finds image by id then removes it from observation.
  # If it's the thumbnail, changes thumbnail to next available image.
  # Saves change to thumbnail, might save change to image.
  # Returns image instance.
  def remove_image_by_id(id)
    img = nil
    if id != 0
      img = Image.find(id)
      if img
        img.observations.delete(self)
        self.images.delete(img)
        if self.thumb_image_id == id.to_i
          if self.images != []
            self.thumb_image = self.images[0]
          else
            self.thumb_image_id = nil
          end
          self.save
        end
        notify_interested_users(:removed_image)
      end
    end
    img
  end

  # Always returns empty string.  Used by form?
  def idstr
    ''
  end

  # Adds error if couldn't find image with the given id.  Used by form?
  def idstr=(id_field)
    id = id_field.to_i
    img = Image.find(:id => id)
    unless img
      errors.add(:thumb_image_id, :validate_observation_thumb_image_id_invalid.t)
    end
  end

  # Abstraction over self.where and self.location.display_name.  Returns
  # location name as a string, preferring "location" over "where" where both
  # exist.
  def place_name()
    if self.location
      self.location.display_name
    else
      self.where
    end
  end

  # Set both "where" and "location".  If given location doesn't exist, it sets
  # "location" to nil.
  def place_name=(where)
    self.where = where
    self.location = Location.find_by_display_name(where)
  end

  # Admin tool that refreshes the vote cache for all observations with a vote.
  def self.refresh_vote_cache
    for o in Observation.find(:all)
      o.calc_consensus
    end
  end

  # Need this below...
  def save_id_before_destroy
    @old_id = self.id
  end

  # -------------------------------
  #  Notifications due to change.
  # -------------------------------

  def notify_interested_users_after_change
    if !self.id ||
       self.when_changed? ||
       self.where_changed? ||
       self.location_id_changed? ||
       self.notes_changed? ||
       self.specimen_changed? ||
       self.is_collection_location_changed? ||
       self.thumb_image_id_changed?
      notify_interested_users(:change)
    end
  end

  def notify_interested_users_after_destroy
    notify_interested_users(:destroy)
  end

  def notify_interested_users(action)
    # Change can trigger emails.
    sender = self.user
    recipients = []

    # Send to people who have registered interest.
    for interest in Interest.find_all_by_object(self)
      if interest.state
        recipients.push(interest.user)
      end
    end

    # Send notification to all except the person who triggered the change.
    for recipient in recipients.uniq
      if recipient && recipient != sender
        if action == :destroy
          ObservationChangeEmail.destroy_observation(sender, recipient, self)
        elsif action == :change
          ObservationChangeEmail.change_observation(sender, recipient, self)
        else
          ObservationChangeEmail.change_images(sender, recipient, self, action)
        end
      end
    end
  end

################################################################################

  protected

  def validate # :nodoc:
    if !self.when
      errors.add(:when, :validate_observation_when_missing.t)
    end
    if !self.user
      errors.add(:user, :validate_observation_user_missing.t)
    end

    if self.where.to_s.blank? && !location_id
      errors.add(:where, :validate_observation_where_missing.t)
    elsif self.where.to_s.length > 100
      errors.add(:where, :validate_observation_where_too_long.t)
    end
  end
end

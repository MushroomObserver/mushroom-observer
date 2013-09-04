# encoding: utf-8
#
#  = Observation Model
#
#  An Observation is a mushroom seen at a certain Location and time, as
#  recorded by a User.  This is at the core of the site.  It can have any
#  number of Image's, Naming's, Comment's, Interest's.
#
#  == Voting
#
#  Voting is still in a state of flux.  At the moment User's create Naming's
#  and other User's Vote on them.  We combine the Vote's for each Naming, cache
#  the Vote for each Naming in the Naming.  However no Naming necessarily wins
#  -- instead Vote's are tallied for each Synonym (see calc_consensus for full
#  details).  Thus the accepted Name of the winning Synonym is cached in the
#  Observation along with its winning Vote score.
#
#  == Location
#
#  An Observation can belong to either a defined Location (+location+, a
#  Location instance) or an undefined one (+where+, just a String), and even
#  occasionally both (see below).  To make this a little easier, you can refer
#  to +place_name+ instead, which returns the name of whichever is present.
#
#  *NOTE*: We were clearly having trouble making up our mind whether or not to
#  set +where+ when +location+ was present.  The only safe heuristic is to use
#  +location+ if it's present, then fall back on +where+ -- +where+ may or may
#  not be set (or even accurate?) if +location+ is present.
#
#  *NOTE*: If a mushroom is seen at a mushroom fair or an herbarium, we don't
#  necessarily know where the mushroom actually grew.  In this case, we enter
#  the mushroom fair / herbarium as the +place_name+ and set the special flag
#  +is_collection_location+ to false.
#
#  == Attributes
#
#  id::                     Locally unique numerical id, starting at 1.
#  sync_id::                Globally unique alphanumeric id, used to sync with remote servers.
#  created_at::             Date/time it was first created.
#  updated_at::             Date/time it was last updated.
#  user_id::                User that created it.
#  when::                   Date it was seen.
#  where::                  Where it was seen (just a String).
#  location::               Where it was seen (Location).
#  lat::                    Exact latitude of location.
#  long::                   Exact longitude of location.
#  alt::                    Exact altitude of location. (meters)
#  is_collection_location:: Is this where it was growing?
#  name::                   Consensus Name (never deprecated, never nil).
#  vote_cache::             Cache Vote score for the winning Name.
#  thumb_image::            Image to use as thumbnail (if any).
#  specimen::               Does User have a specimen available?
#  notes::                  Arbitrary extra notes supplied by User.
#  num_views::              Number of times it has been viewed.
#  last_view::              Last time it was viewed.
#
#  ==== "Fake" attributes
#  idstr::                  Used by <tt>observer/reuse_image.rhtml</tt>.
#  place_name::             Wrapper on top of +where+ and +location+.  Handles location_format.
#
#  == Class methods
#
#  refresh_vote_cache::     Refresh cache for all Observation's.
#  define_a_location::      Update any observations using the old "where" name.
#
#  == Instance methods
#
#  comments::               List of Comment's attached to this Observation.
#  interests::              List of Interest's attached to this Observation.
#  species_lists::          List of SpeciesList's that contain this Observation.
#
#  ==== Name Formats
#  text_name::              Plain text.
#  format_name::            Textilized. (uses name.observation_name)
#  unique_text_name::       Plain text, with id added to make unique.
#  unique_format_name::     Textilized, with id added to make unique.
#  default_specimen_label:: 
#
#  ==== Namings and Votes
#  name::                   Conensus Name instance. (never nil)
#  namings::                List of Naming's proposed for this Observation.
#  name_been_proposed?::    Has someone proposed this Name already?
#  owner_voted?::           Has the owner voted on a given Naming?
#  user_voted?::            Has a given User voted on a given Naming?
#  owners_vote::            Get the owner's Vote on a given Naming.
#  users_vote::             Get a given User's Vote on a given Naming.
#  owners_votes::           Get all of the onwer's Vote's for this Observation.
#  users_votes::            Get all of a given User's Vote's for this Observation.
#  is_owners_favorite?::    Is a given naming the owner's favorite?
#  is_users_favorite?::     Is a given naming a given user's favorite?
#  vote_percent::           Convert Vote score to percentage.
#  change_vote::            Change a given User's Vote for a given Naming.
#  consensus_naming::       Guess which Naming is responsible for consensus.
#  calc_consensus::         Calculate and cache the consensus naming/name.
#  review_status::          Decide what the review status is for this Observation.
#  lookup_naming::          Return corresponding Naming instance from this Observation's namings association.
#  dump_votes::             Dump all the Naming and Vote info as known by this Observation and its associations.
#
#  ==== Images
#  images::                 List of Image's attached to this Observation.
#  add_image::              Attach an Image.
#  remove_image::           Remove an Image.
#
#  ==== Projects
#  has_edit_permission?::   Check if user has permission to edit this observation.
#
#  ==== Callbacks
#  add_spl_callback::           After add: update contribution.
#  remove_spl_callback::        After remove: update contribution.
#  notify_species_lists::       Before destroy: log destruction on species_lists.
#  destroy_dependents::         After destroy: destroy Naming's.
#  notify_users_after_change::  After save: call notify_users (if important).
#  notify_users_after_destroy:: After destroy: call notify_users.
#  notify_users::               After save/destroy/image: send email.
#  announce_consensus_change::  After consensus changes: send email.
#
################################################################################

class Observation < AbstractModel
  belongs_to :thumb_image, :class_name => "Image", :foreign_key => "thumb_image_id"
  belongs_to :name      # (used to cache consensus name)
  belongs_to :location
  belongs_to :rss_log
  belongs_to :user

  has_many :votes
  has_many :comments,  :as => :target, :dependent => :destroy
  has_many :interests, :as => :target, :dependent => :destroy

  # DO NOT use :dependent => :destroy -- this causes it to recalc the
  # consensus several times and send bogus emails!!
  has_many :namings

  has_and_belongs_to_many :images
  has_and_belongs_to_many :projects
  has_and_belongs_to_many :species_lists, :after_add => :add_spl_callback,
                                          :before_remove => :remove_spl_callback
  has_and_belongs_to_many :specimens

  after_update   :notify_users_after_change
  before_destroy :notify_species_lists
  after_destroy  :notify_users_after_destroy
  after_destroy  :destroy_dependents

  # Automatically (but silently) log destruction.
  self.autolog_events = [:destroyed]
  
  # Override the default show_controller
  def self.show_controller
    'observer'
  end

  def is_location?
    false
  end

  def is_observation?
    true
  end

  # Always returns empty string.  (Used by
  # <tt>observer/reuse_image.rhtml</tt>.)
  def idstr
    ''
  end

  # Adds error if couldn't find image with the given id.  (Used by
  # <tt>observer/reuse_image.rhtml</tt>.)
  def idstr=(id_field)
    id = id_field.to_i
    img = Image.find(:id => id)
    unless img
      errors.add(:thumb_image_id, :validate_observation_thumb_image_id_invalid.t)
    end
  end

  def raw_place_name
    if location
      location.name
    else
      self.where
    end
  end

  # Abstraction over +where+ and +location.display_name+.  Returns Location
  # name as a string, preferring +location+ over +where+ wherever both exist.
  # Also applies the location_format of the current user (defaults to :postal).
  def place_name
    if location
      location.display_name
    elsif User.current_location_format == :scientific
      Location.reverse_name(self.where)
    else
      self.where
    end
  end

  # Set +where+ or +location+, depending on whether a Location is defined with
  # the given +display_name+.  (Fills the other in with +nil+.)
  # Adjusts for the current user's location_format as well.
  def place_name=(place_name)
    place_name = place_name.strip_squeeze
    where = if User.current_location_format == :scientific
      Location.reverse_name(place_name)
    else
      place_name
    end
    if loc = Location.find_by_name(where)
      self.where = nil
      self.location = loc
    else
      self.where = where
      self.location = nil
    end
  end

  # Useful for forms in which date is entered in YYYYMMDD format: When form tag
  # helper creates input field, it reads obs.when_str and gets date in
  # YYYYMMDD.  When form submits, assigning string to obs.when_str saves string
  # verbatim in @when_str, and if it is valid, sets the actual when field.
  # When you go to save the observation, it detects invalid format and prevents
  # save.  When it renders form again, it notes the error, populates the input
  # field with the old invalid string for editing, and colors it red.
  def when_str
    if @when_str
      @when_str
    else
      self.when.strftime('%Y-%m-%d')
    end
  end
  def when_str=(x)
    @when_str = x
    self.when = x if Date.parse(x)
    return x
  end

  def lat=(x)
    val = Location.parse_latitude(x)
    val = x if val.nil? and !x.blank?
    write_attribute(:lat, val)
  end

  def long=(x)
    val = Location.parse_longitude(x)
    val = x if val.nil? and !x.blank?
    write_attribute(:long, val)
  end

  def alt=(x)
    val = Location.parse_altitude(x)
    val = x if val.nil? and !x.blank?
    write_attribute(:alt, val)
  end

  # Is lat/long more than 10% outside of location extents?
  def lat_long_dubious?
    lat and location and not location.lat_long_close?(lat, long)
  end

  ##############################################################################
  #
  #  :section: Namings and Votes
  #
  ##############################################################################

  # Name in plain text, never nil.
  def text_name
    name.real_search_name
  end

  # Name in plain text with id to make it unique, never nil.
  def unique_text_name
    name.real_search_name + " (#{id || '?'})"
  end

  # Textile-marked-up name, never nil.
  def format_name
    name.observation_name
  end

  # Textile-marked-up name with id to make it unique, never nil.
  def unique_format_name
    name.observation_name + " (#{id || '?'})"
  end
  
  def default_specimen_label
    Herbarium.default_specimen_label(name.text_name, id)
  end

  # Look up the corresponding instance in our namings association.  If we are
  # careful to keep all the operations within the tree of assocations of the
  # observations, we should never need to reload anything.
  def lookup_naming(naming)
    namings.select {|n| n == naming}.first or
      raise ActiveRecord::RecordNotFound, "Observation doesn't have naming with ID=#{naming.id}"
  end

  # Dump out the sitatuation as the observation sees it.  Useful for debugging
  # problems with reloading requirements.
  def dump_votes
    namings.map do |n|
      "#{n.id} #{n.name.real_search_name}: " +
      (n.votes.empty? ? "no votes" : n.votes.map do |v|
        "#{v.user.login}=#{v.value}" + (v.favorite ? '(*)' : '')
      end.join(', '))
    end.join("\n")
  end

  # Has anyone proposed a given Name yet for this observation?
  def name_been_proposed?(name)
    namings.select {|n| n.name == name}.length > 0
  end

  # Has the owner voted on a given Naming?
  def owner_voted?(naming)
    !!lookup_naming(naming).users_vote(user)
  end

  # Has a given User owner voted on a given Naming?
  def user_voted?(naming, user)
    !!lookup_naming(naming).users_vote(user)
  end

  # Get the owner's Vote on a given Naming.
  def owners_vote(naming)
    lookup_naming(naming).users_vote(user)
  end

  # Get a given User's Vote on a given Naming.
  def users_vote(naming, user)
    lookup_naming(naming).users_vote(user)
  end

  # Returns true if a given naming has received the highest positive vote from
  # the owner of this observation.  Note, multiple namings can return true for
  # a given observation.
  def is_owners_favorite?(naming)
    lookup_naming(naming).is_users_favorite?(user)
  end

  # Returns true if a given naming has received the highest positive vote from
  # the given user (among namings for this observation).  Note, multiple
  # namings can return true for a given user and observation.
  def is_users_favorite?(naming, user)
    lookup_naming(naming).is_users_favorite?(user)
  end

  # Get a list of the owner's Votes for this Observation.
  def owners_votes
    users_votes(user)
  end

  # Get a list of this User's Votes for this Observation.
  def users_votes(user)
    result = []
    for n in namings
      if v = n.users_vote(user)
        result << v
      end
    end
    return result
  end

  # Convert cached Vote score to percentage.
  def vote_percent
    Vote.percent(vote_cache)
  end

  # Change User's Vote for this naming.  Automatically recalculates the
  # consensus for the Observation in question if anything is changed.  Returns
  # true if something was changed.
  def change_vote(naming, value, user=User.current)
    result = false
    naming = lookup_naming(naming)
    vote = naming.users_vote(user)

    # This special value means destroy vote.
    if value == Vote.delete_vote
      if vote
        naming.votes.delete(vote)
        result = true

        # If this was one of the old favorites, we might have to elect new.
        if vote.favorite

          # Get the max positive vote.
          max = 0
          for v in users_votes(user)
            if v.value > max
              max = v.value
            end
          end

          # If any, mark all votes at that level "favorite".
          if max > 0
            for v in users_votes(user)
              if (v.value == max) and
                 !v.favorite
                v.favorite = true
                v.save
              end
            end
          end
        end
      end

    # If no existing vote, or if changing value.
    elsif !vote || (vote.value != value)
      result = true

      # First downgrade any existing 100% votes (if casting a 100% vote).
      v80 = Vote.next_best_vote
      if value > v80
        for v in users_votes(user)
          if v.value > v80
            v.value = v80
            v.save
          end
        end
      end

      # Is this vote going to become the favorite?
      favorite = false
      if value > 0
        favorite = true
        for v in users_votes(user)
          # If any other vote higher, this is not the favorite.
          if v.value > value
            favorite = false
            break
          # If any other votes are lower, those will not be favorite.
          elsif (v.value < value) and
                v.favorite
            v.favorite = false
            v.save
          end
        end
      end

      # Create vote if none exists.
      if !vote
        naming.votes.create!(
          :user        => user,
          :observation => self,
          :value       => value,
          :favorite    => favorite
        )

      # Change vote if it exists.
      else
        vote.value    = value
        vote.favorite = favorite
        vote.save
      end
    end

    # Update consensus if anything changed.
    calc_consensus if result

    return result
  end

  # Try to guess which Naming is responsible for the consensus.  This will
  # always return a Naming, no matter how ambiguous, unless there are no
  # namings.
  def consensus_naming
    result = nil

    # First, get the Naming(s) for this Name, if any exists.
    matches = namings.select {|n| n.name_id == name_id}

    # If not, it means that a deprecated Synonym won.  Look up all Namings
    # for Synonyms of the consensus Name.
    if matches == [] && name && name.synonym
      synonyms = name.synonyms
      matches = namings.select {|n| synonyms.include?(n.name)}
    end

    # Only one match -- easy!
    if matches.length == 1
      result = matches.first

    # More than one match: take the one with the highest vote.
    elsif best_naming = matches.first
      best_value = matches.first.vote_cache
      for naming in matches
        if naming.vote_cache > best_value
          best_naming = naming
          best_value  = naming.vote_cache
        end
      end
      result = best_naming
    end

    return result
  end

  # Get the community consensus on what the name should be.  It just adds up
  # the votes weighted by user contribution, and picks the winner.  To break a
  # tie it takes the one with the most votes (again weighted by contribution).
  # Failing that it takes the oldest one.  Note, it lumps all synonyms together
  # when deciding the winning "taxon", using votes for the separate synonyms
  # only when there are multiple "accepted" names for the winning taxon.
  #
  # Returns Naming instance or nil.  Refreshes vote_cache as a side-effect.
  def calc_consensus(debug=false)
    reload
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
    for naming in namings
      naming_id = naming.id
      name_id = naming.name_id
      name_ages[name_id] = naming.created_at if !name_ages[name_id] || naming.created_at < name_ages[name_id]
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
          taxon_ages[taxon_id] = naming.created_at if !taxon_ages[taxon_id] || naming.created_at < taxon_ages[taxon_id]
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
        for naming in namings
          if naming.name.synonym_id.to_s == match[2]
            best = naming.name
            break
          end
        end
      else
        best = Name.find(match[2].to_i)
      end
    end
result += "unmash: best=#{best ? best.real_text_name : "nil"}<br/>" if debug

    # Now deal with synonymy properly.  If there is a single accepted name,
    # great, otherwise we need to somehow disambiguate.
    if best && best.synonym
      # This does not allow the community to choose a deprecated synonym over
      # an approved synonym.  See obs #45234 for reasonable-use case.
      # names = best.approved_synonyms
      # names = best.synonyms if names.length == 0
      names = best.synonyms
      if names.length == 1
        best = names.first
      elsif names.length > 1
result += "Multiple synonyms: #{names.map {|x| x.id}.join(', ')}<br>" if debug

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
result += "#{self.name_id}: val=#{val} wgt=#{wgt} age=#{age}<br/>" if debug
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
result += "unsynonymize: best=#{best ? best.real_text_name : "nil"}<br/>" if debug

    # This should only occur for observations created by
    # species_list.construct_observation(), which doesn't necessarily create
    # any votes associated with its naming.  Therefore this should only ever
    # happen when there is a single naming, so there is nothing arbitray in
    # using first.  (I think it can also happen if zero-weighted users are
    # voting.)
    best = namings.first.name if !best && namings && namings.length > 0
    best = Name.unknown if !best
result += "fallback: best=#{best ? best.real_text_name : 'nil'}" if debug

    # Make changes permanent.
    old = self.name
    if (self.name != best) or
       (self.vote_cache != best_val)
      self.name = best
      self.vote_cache = best_val
      self.save
    end

    # Log change if actually is a change.
    if best != old
      announce_consensus_change(old, best)
    end

return result if debug
  end

  # Admin tool that refreshes the vote cache for all observations with a vote.
  def self.refresh_vote_cache
    for o in Observation.find(:all)
      o.calc_consensus
    end
  end

  # Return the review status based on the Vote's on the consensus Name by
  # current reviewers.  Possible return values:
  #
  # unreviewed:: No reviewers have voted for the consensus.
  # inaccurate:: Some reviewer doubts the consensus (vote.value < 0).
  # unvetted::   Some reviewer is not completely confident in this naming (vote.value < Vote#maximum_vote).
  # vetted::     All reviewers that have voted on the current consensus fully support this name (vote.value = Vote#maximum_vote).
  #
  # *NOTE*: It probably makes sense to cache this result at some point.
  #
  # *NOTE*: This checks all Vote's for Synonym Naming's, taking each reviewer's
  # highest Vote (if they voted for multiple Synonym's).
  #
  def review_status

    # Get list of Name ids we care about.
    name_ids = [name_id]
    if name.synonym_id
      name_ids = Name.connection.select_values %(
        SELECT `id` FROM `names` WHERE `synonym_id` = '#{synonym_id}'
      )
    end

    # Get list of User ids for reviewers.
    group = UserGroup.find_by_name('reviewers')
    user_ids = User.connection.select_values %(
      SELECT `user_id` FROM `user_groups_users`
      WHERE `user_group_id` = #{group.id}
    )

    # Get all the reviewers' Vote's for these Name's.
    # Order of conditions makes no difference: query times are around 0.05 sec.
    data = Vote.connection.select_rows %(
      SELECT vote.user_id, vote.value
      FROM `votes`, `namings`
      WHERE votes.observation_id = #{id} AND
            votes.naming_id = namings.id AND
            namings.name_id IN (#{name_ids.map(&:to_s).uniq.join(',')}) AND
            votes.user_id IN (#{user_ids.map(&:to_s).uniq.join(',')})
    )

    # Get highest vote for each User.
    votes = {}
    for user_id, value in data
      value = value.to_f
      if votes[user_id]
        votes[user_id] = value if votes[user_id] < value
      else
        votes[user_id] = value
      end
    end

    # Apply heuristics to determine review status.
    status = :unreviewed
    v100 = Vote.maximum_vote.to_f
    for value in votes.values
      if value < 0
        status = :inaccurate
        break
      elsif status != :inaccurate
        if value != v100
          status = :unvetted
        elsif status == :unreviewed
          status = :vetted
        end
      end
    end

    return status
  end

  ################################################################################
  #
  #  :section: Images
  #
  ################################################################################

  # Add Image to this Observation, making it the thumbnail if none set already.
  # Saves changes.  Returns Image.
  def add_image(img)
    if !images.include?(img)
      images << img
      unless thumb_image
        self.thumb_image = img
        self.save
      end
      notify_users(:added_image)
    end
    return img
  end

  # Removes an Image from this Observation.  If it's the thumbnail, changes
  # thumbnail to next available Image.  Saves change to thumbnail, might save
  # change to Image.  Returns Image.
  def remove_image(img)
    if images.include?(img)
      images.delete(img)
      if thumb_image_id == img.id
        if images != []
          self.thumb_image = img2 = images.first
        else
          self.thumb_image = nil
        end
        self.save
      end
      notify_users(:removed_image)
    end
    return img
  end

  ################################################################################
  #
  #  :section: Projects
  #
  ################################################################################

  def has_edit_permission?(user=User.current)
    Project.has_edit_permission?(self, user)
  end

  ################################################################################
  #
  #  :section: Callbacks
  #
  ################################################################################

  # Callback that updates a User's contribution after adding an Observation to
  # a SpeciesList.
  def add_spl_callback(o)
    SiteData.update_contribution(:add, :species_list_entries, user_id)
  end

  # Callback that updates a User's contribution after removing an Observation
  # from a SpeciesList.
  def remove_spl_callback(o)
    SiteData.update_contribution(:del, :species_list_entries, user_id)
  end

  # Callback that logs an Observation's destruction on all of its
  # SpeciesList's.  (Also saves list of Namings so they can be destroyed
  # by hand afterword without causing superfluous calc_consensuses.)
  def notify_species_lists
    # Tell all the species lists it belonged to.
    for spl in species_lists
      spl.log(:log_observation_destroyed2, :name => unique_format_name,
              :touch => false)
    end

    # Save namings so we can delete them after it's dead.
    @old_namings = namings
  end

  # Callback that destroys an Observation's Naming's (carefully) after the
  # Observation is destroyed.
  def destroy_dependents
    for naming in @old_namings
      naming.observation = nil # (tells it not to recalc consensus)
      naming.destroy
    end
  end

  # Callback that sends email notifications after save.
  def notify_users_after_change
    if !id ||
       when_changed? ||
       where_changed? ||
       location_id_changed? ||
       notes_changed? ||
       specimen_changed? ||
       is_collection_location_changed? ||
       thumb_image_id_changed?
      notify_users(:change)
    end
  end

  # Callback that sends email notifications after destroy.
  def notify_users_after_destroy
    notify_users(:destroy)
  end

  # Send email notifications upon change to Observation.  Several actions are
  # possible:
  #
  # added_image::   Image was added.
  # removed_image:: Image was removed.
  # change::        Other changes (e.g. to notes).
  # destroy::       Observation destroyed.
  #
  #   obs.images << Image.create
  #   obs.notify_users(:added_image)
  #
  def notify_users(action)
    sender = user
    recipients = []

    # Send to people who have registered interest.
    for interest in interests
      if interest.state
        recipients.push(interest.user)
      end
    end

    # Tell masochists who want to know about all observation changes.
    for user in User.find_all_by_email_observations_all(true)
      recipients.push(user)
    end

    # Send notification to all except the person who triggered the change.
    for recipient in recipients.uniq
      if recipient && recipient != sender
        if action == :destroy
          QueuedEmail::ObservationChange.destroy_observation(sender, recipient, self)
        elsif action == :change
          QueuedEmail::ObservationChange.change_observation(sender, recipient, self)
        else
          QueuedEmail::ObservationChange.change_images(sender, recipient, self, action)
        end
      end
    end
  end

  # Send email notifications upon change to consensus.
  #
  #   old_name = obs.name
  #   obs.name = new_name
  #   obs.announce_consensus_change(old_name, new_name)
  #
  def announce_consensus_change(old_name, new_name)
    if old_name
      log(:log_consensus_changed, :old => old_name.display_name,
                                  :new => new_name.display_name)
    else
      log(:log_consensus_created_at, :name => new_name.display_name)
    end

    # Change can trigger emails.
    owner  = self.user
    sender = User.current
    recipients = []

    # Tell owner of observation if they want.
    recipients.push(owner) if owner && owner.email_observations_consensus

    # Send to people who have registered interest.
    # Also remove everyone who has explicitly said they are NOT interested.
    for interest in interests
      if interest.state
        recipients.push(interest.user)
      else
        recipients.delete(interest.user)
      end
    end

    # Send notification to all except the person who triggered the change.
    for recipient in recipients.uniq - [sender]
      if recipient.created_here
        QueuedEmail::ConsensusChange.create_email(sender, recipient,
                                                  self, old_name, new_name)
      end
    end
  end

  # After defining a location, update any lists using old "where" name.
  def self.define_a_location(location, old_name)
    connection.update(%(
      UPDATE observations SET `where` = NULL, location_id = #{location.id}
      WHERE `where` = "#{old_name.gsub('"', '\\"')}"
    ))
    # (no transactions necessary: creating location on foreign server
    # should initiate identical action)
  end
  
################################################################################

protected

  def validate # :nodoc:
    # Clean off leading/trailing whitespace from +where+.
    self.where = self.where.strip_squeeze if self.where
    self.where = nil if self.where == ''

    if !self.when
      self.when ||= Time.now
      # errors.add(:when, :validate_observation_when_missing.t)
    elsif self.when.is_a?(Date) && self.when > Date.today + 1.day
      errors.add(:when, "self.when=#{self.when.class.name}:#{self.when} Date.today=#{Date.today}")
      errors.add(:when, :validate_observation_future_time.t)
    elsif self.when.is_a?(Time) && self.when > Time.now + 1.day
      errors.add(:when, "self.when=#{self.when.class.name}:#{self.when} Time.now=#{Time.now+6.hours}")
      errors.add(:when, :validate_observation_future_time.t)
    end
    if !user && !User.current
      errors.add(:user, :validate_observation_user_missing.t)
    end

    if self.where.to_s.blank? && !location_id
      self.location = Location.unknown
      # errors.add(:where, :validate_observation_where_missing.t)
    elsif self.where.to_s.binary_length > 1024
      errors.add(:where, :validate_observation_where_too_long.t)
    end

    if lat.blank? and !long.blank? or
       !lat.blank? and !Location.parse_latitude(lat)
      errors.add(:lat, :runtime_lat_long_error.t)
    end
    if !lat.blank? and long.blank? or
       !long.blank? and !Location.parse_longitude(long)
      errors.add(:long, :runtime_lat_long_error.t)
    end
    if !alt.blank? and !Location.parse_altitude(alt)
      errors.add(:alt, :runtime_altitude_error.t)
    end

    if @when_str and !Date.parse(@when_str)
      errors.add(:when_str, :runtime_date_should_be_yyyymmdd.t)
    end
  end
end

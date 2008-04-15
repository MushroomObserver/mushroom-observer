# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

require 'active_record_extensions'

# RSS log:
#   log(msg, touch)      Add message to log (creating log if necessary).
#   orphan_log(entry)    Same as log() except observation is about to go away.
#   touch                [huh? what is @modified used for?]
#
# Naming stuff:
#   calc_consensus          Calculate and cache the consensus naming/name.
#   naming                  Conensus Naming instance. (can be nil)
#   name                    Conensus Name instance.   (never nil)
#   preferred_name(user)    Name instance.   (never nil)
#   name_been_proposed?(n)  Has someone proposed this name already?
#   text_name(user)         Plain text.
#   format_name(user)       Textilized.
#   unique_text_name(user)  Same as above, with id added to make unique.
#   unique_format_name(user)
#     Notes: these last six use the current user's preferred name if it
#     exists, otherwise uses the consensus (as cached via calc_conensus).
#     These are the six methods views should use, not name/naming.
#   refresh_vote_cache      Admin tool to refresh cache across all observations.
#
# Image stuff:
#   add_image(img)         Add img to obv.
#   add_image_by_id(id)    Add img to obv.
#   remove_image_by_id(id) Remove img from obv.
#   idstr                  [These two must somehow be used implicitly
#   idstr=(id_field)       by the view.]
#
# Location/Where ambiguity:
#   place_name             Get location name or where, whichever exists.
#   place_name=            Set where if cannot find location by that name.
#
# Protected:
#   self.all_observations  List of observations sorted by date, newest first.
#
# Validates:
#   requires presence of user and location

class Observation < ActiveRecord::Base
  has_and_belongs_to_many :images
  has_and_belongs_to_many :species_lists
  belongs_to :thumb_image, :class_name => "Image", :foreign_key => "thumb_image_id"
  has_many :comments,          :dependent => :destroy
  has_many :namings,           :dependent => :destroy
  has_one :rss_log
  belongs_to :name      # (used to cache consensus name)
  belongs_to :location
  belongs_to :user

  attr_display_names({
    :when  => "date",
    :where => "location"
  })

  # Creates rss_log if necessary.
  def log(msg, touch)
    if self.rss_log.nil?
      self.rss_log = RssLog.new
    end
    self.rss_log.addWithDate(msg, touch)
  end

  # Creates rss_log if necessary.
  def orphan_log(entry)
    self.log(entry, false) # Ensures that self.rss_log exists
    self.rss_log.observation = nil
    self.rss_log.add(self.text_name, false)
    self.rss_log.save
  end

  # Just sets @modified to Time.now -- huh?
  def touch
    @modified = Time.new
  end

################################################################################

  # Get the community consensus on what the name should be.  It just adds up
  # the votes (eventually I would like to weight by contribution), and picks
  # the winner.  To break a tie it takes the one with the most votes (again
  # I would like to weight by contribution).  Failing that it takes the oldest
  # one.  Note, it now disregards any namings that only the owner has voted on,
  # unless there are no non-owner votes > 50.  Note, it now also lumps all
  # synonyms together when deciding the winning "taxon", using votes for the
  # separate synonyms only when there are multiple "accepted" names for the
  # winning taxon.
  # Returns Naming instance or nil.
  def calc_consensus
#result = ""

    # [Now that we consider all votes, this is all superfluous. -JPH 20080313]
    # # Gather some handy overall vote stats.
    # any_votes_at_all = false   # Are there any votes for any namings at all?
    # any_positive_votes = false # Are there any "positive" votes by non-owners, i.e. votes > 50%?
    # nonowner_voted = {}        # Has anyone other than the owner voted for a given naming?
    # for naming in self.namings
    #   naming_id = naming.id
    #   nonowner_voted[naming_id] = false
    #   for vote in naming.votes
    #     any_votes_at_all = true
    #     if vote.user_id != naming.user_id
    #       nonowner_voted[naming_id] = true
    #       any_positive_votes = true if vote.value > 50
    #     end
    #   end
    # end

    # Gather votes for names and synonyms.  Note that this is trickier than one would expect
    # since it is possible to propose several synonyms for a single observation, and even
    # worse perhaps, one can even propose the very same name multiple times.  Thus a user can
    # potentially vote for a given *name* (not naming) multiple times.  Likewise, of course,
    # for synonyms.  I choose the strongest vote in such cases.
    name_votes  = {}  # Records the strongest vote for a given name for a given user.
    taxon_votes = {}  # Records the strongest vote for any names in a group of synonyms for a given user.
    name_ages   = {}  # Records the oldest date that a name was proposed.
    taxon_ages  = {}  # Records the oldest date that a taxon was proposed.
    user_wgts   = {}  # Caches user rankings.
    for naming in self.namings
      naming_id = naming.id
      # [We're considering all votes now. -JPH 20080313]
      # # First, are we even going to consider this naming?
      # if nonowner_voted[naming_id] || !any_positive_votes
      name_id = naming.name_id
      name_ages[name_id] = naming.created if !name_ages[name_id] || naming.created < name_ages[name_id]
      # Go through all the votes for this naming.  Should be zero or one per user.
      for vote in naming.votes
        user_id = vote.user_id
        val = vote.value
        wgt = user_wgts[user_id] 
        if wgt.nil?
          wgt = user_wgts[user_id] = vote.user_weight
        end
        # It may be possible in the future for us to weight some "special" users zero, who knows...
        # (It can cause a division by zero below if we ignore zero weights.)
        if wgt > 0
          # Record best vote for this user for this name.  This will be used later
          # to determine which name wins in the case of the winning taxon (see below)
          # having multiple accepted names.
          name_votes[name_id] = {} if !name_votes[name_id]
          if !name_votes[name_id][user_id] ||
              name_votes[name_id][user_id][0] < val
            name_votes[name_id][user_id] = [val, wgt]
          end
          # Record best vote for this user for this group of synonyms.  (Since not all taxa
          # have synonyms, I've got to create a "fake" id that uses the synonym id if it exists,
          # else uses the name id, but still keeps them separate.)
          taxon_id = naming.name.synonym ? "s" + naming.name.synonym_id.to_s : "n" + name_id.to_s
          taxon_ages[taxon_id] = naming.created if !taxon_ages[taxon_id] || naming.created < taxon_ages[taxon_id]
          taxon_votes[taxon_id] = {} if !taxon_votes[taxon_id]
          if !taxon_votes[taxon_id][user_id] ||
              taxon_votes[taxon_id][user_id][0] < val
            taxon_votes[taxon_id][user_id] = [val, wgt]
          end
        end
      end
      # end
    end

    # Now that we've weeded out potential duplicate votes, we can combine them safely.
    votes = {}
    for taxon_id in taxon_votes.keys
      vote = votes[taxon_id] = [0, 0]
      for user_id in taxon_votes[taxon_id].keys
        user_vote = taxon_votes[taxon_id][user_id]
        val = user_vote[0]
        wgt = user_vote[1]
        vote[0] += val * wgt
        vote[1] += wgt
#result += "vote: taxon_id=#{taxon_id}, user_id=#{user_id}, val=#{val}, wgt=#{wgt} (#{vote[0]}, #{vote[1]}) (#{votes[taxon_id][0]}, #{votes[taxon_id][1]})<br/>"
      end
    end

    # Now we can determine the winner among the set of synonym-groups.  (Nathan calls
    # these synonym-groups "taxa", because it better uniquely represents the underlying
    # mushroom taxon, while it might have multiple names.)
    best_val = nil
    best_wgt = nil
    best_age = nil
    best_id  = nil
    for taxon_id in votes.keys
      wgt = votes[taxon_id][1]
      val = votes[taxon_id][0].to_f / (wgt + 1.0)
      age = taxon_ages[taxon_id]
#result += "#{taxon_id}: val=#{val} wgt=#{wgt} age=#{age}<br/>"
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
#result += "best: id=#{best_id}, val=#{best_val}, wgt=#{best_wgt}, age=#{best_age}<br/>"

    # Reverse our kludge that mashed names-without-synonyms and synonym-groups together.
    # In the end we just want a name.
    if best_id
      match = /^(.)(\d+)/.match(best_id)
      # Synonym id: go through namings and pick first one that belongs to this synonym group.
      # Any will do for our purposes, because we will convert it to the currently accepted name below.
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
#result += "unmash: best=#{best ? best.text_name : "nil"}<br/>"

    # Now deal with synonymy properly.  If there is a single accepted name, great,
    # otherwise we need to somehow disambiguate.
    if best && best.synonym
      names = best.approved_synonyms
      names = best.synonym.names if names.length == 0
      if names.length == 1
        best = names.first
      elsif names.length > 1

        # First combine votes for each name; exactly analagous to what we did with taxa above.
        votes = {}
        for name_id in name_votes.keys
          vote = votes[name_id] = [0, 0]
          for user_id in name_votes[name_id].keys
            user_vote = name_votes[name_id][user_id]
            wgt = user_vote[1]
            val = user_vote[0].to_f / (wgt + 1.0)
            vote[0] += val * wgt
            vote[1] += wgt
          end
        end

        # Now pick the winner among the ambiguous names.  If none are voted on, just pick
        # the first one (I grow weary of these games).  This latter is all too real of a
        # possibility: users may vigorously debate deprecated names, then at some later
        # date two *new* names are created for the taxon, both are considered "accepted"
        # until the scientific community rules definitively.  Now we have two possible
        # names winning, but no votes on either!  If you have a problem with the one I
        # chose, then vote on the damned thing, already! :)
        best_val2 = nil
        best_wgt2 = nil
        best_age2 = nil
        best_id2  = nil
        for name in names
          name_id = name.id
          vote = votes[name_id]
          if vote
            val = vote[0]
            wgt = vote[1]
            age = name_ages[name_id]
            if best_val2.nil? ||
               val > best_val2 || val == best_val2 && (
               wgt > best_wgt2 || wgt == best_wgt2 && (
               age < best_ag2e
              ))
              best_val2 = val
              best_wgt2 = wgt
              best_age2 = age
              best_id2  = name_id
            end
          end
        end
        best = best_id2 ? Name.find(best_id2) : names.first
      end
    end
#result += "unsynonymize: best=#{best ? best.text_name : "nil"}<br/>"

    # This should only occur for observations created by species_list.construct_observation(),
    # which doesn't necessarily create any votes associated with its naming.  Therefore this should
    # only ever happen when there is a single naming, so there is nothing arbitray in using first.
    # (I think it can also happen if zero-weighted users are voting.)
    best = self.namings.first.name if !best && self.namings && self.namings.length > 0
    best = Name.unknown if !best
#result += "fallback: best=#{best ? best.text_name : "nil"}<br/>"

    # Make changes permanent and log them.
    old = self.name
    self.name = best
    self.vote_cache = best_val
    self.save
    if best != old && old
      self.log("Consensus rejected #{old.observation_name} in favor of #{best.observation_name}", true)
    elsif best != old
      self.log("Consensus established: #{best.observation_name}", true)
    end

#return result
  end

################################################################################

  # Look up the user's preferred name.  The logic is:
  # If the user has voted 100% for something, use that.
  # Otherwise use the community consensus.
  def preferred_name(user=nil)
    v100 = Vote.maximum_vote
    if user
      for naming in self.namings
        vote = naming.users_vote(user)
        if vote && vote.value == v100
          return naming.name
        end
      end
    end
    return self.name
  end

  # Various formats using the preferred_name.
  def text_name(user=nil)
    self.preferred_name(user).search_name
  end

  def unique_text_name(user=nil)
    str = self.preferred_name(user).search_name
    "%s (%s)" % [str, self.id]
  end

  def format_name(user=nil)
    self.preferred_name(user).observation_name
  end

  def unique_format_name(user=nil)
    str = self.preferred_name(user).observation_name
    "%s (%s)" % [str, self.id]
  end

  # ----------------------------------------

  # Has anyone proposed a given name yet for this observation?
  def name_been_proposed?(name)
    self.namings.select {|n| n.name == name}.length > 0
  end

  # ----------------------------------------

  # Add image to this observation, making thumbnail if none set already.
  # Saves changes.  Returns nothing.
  def add_image(img)
    img.observations << self
    unless self.thumb_image
      self.thumb_image = img
      self.save
    end
  end

  # Finds image by id then calls add_image().
  # Saves changes.  Returns image instance.
  def add_image_by_id(id)
    result = nil
    if id != 0
      result = Image.find(id)
      if result
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
      end
    end
    img
  end

  # Returns empty string.  [huh?]
  def idstr
    ''
  end

  # Adds error if couldn't find image with id in id_field.
  # Changes nothing.
  # Returns nothing.
  def idstr=(id_field)
    id = id_field.to_i
    img = Image.find(:id => id)
    unless img
      errors.add(:notes, "unable to find a corresponding image")
    end
  end

  # Abstraction over self.where and self.location.display_name
  # Prefer location to where
  def place_name()
    if self.location
      self.location.display_name
    else
      self.where
    end
  end

  def place_name=(where)
    self.where = where
    self.location = Location.find_by_display_name(where)
  end

  # Admin tool that refreshes the vote cache for all observations with a vote.
  def self.refresh_vote_cache

    # Catch all observations with no namings.
    # self.connection.update %(
    #   UPDATE observations
    #   SET vote_cache = NULL
    #   WHERE(
    #     SELECT count(votes.value)
    #     FROM namings, votes
    #     WHERE namings.observation_id = observations.id and
    #           votes.naming_id = namings.id
    #   ) = 0
    # )

    # # Catch simple case of observations with only one vote.
    # self.connection.update %(
    #   UPDATE observations
    #   SET vote_cache=(
    #     SELECT max(votes.value)/2
    #     FROM namings, votes
    #     WHERE namings.observation_id = observations.id and
    #           votes.naming_id = namings.id
    #   )
    #   WHERE(
    #     SELECT count(votes.value)
    #     FROM namings, votes
    #     WHERE namings.observation_id = observations.id and
    #           votes.naming_id = namings.id
    #   ) = 1
    # )

    # Now get list of all the rest.
    data = self.connection.select_all %(
      SELECT id
      FROM observations
      WHERE(
        SELECT count(votes.value)
        FROM namings, votes
        WHERE namings.observation_id = observations.id and
              votes.naming_id = namings.id
      ) > 1
    )

    # Recalculate consensus for these one at a time.
    for d in data
      id = d['id']
      o = Observation.find(id)
      o.calc_consensus
    end
  end

  # [This *must* be a typo... -JPH 20080327]
  # protected
  # def self.all_observations
  #   find(:all,
  #        :order => "'when' desc")
  # end

  # ----------------------------------------

  protected

  # List of observations sorted by date, newest first.
  def self.all_observations
    find(:all,
         :order => "'when' desc")
  end

  def validate
    errors.add(:where, "can't be blank") if (where.nil? || where == '') && location_id.nil?
  end

  validates_presence_of :user
end

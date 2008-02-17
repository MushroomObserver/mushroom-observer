# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

# These are used to create temporary storage that acts like a normal
# database column.  They're used (implicity no doubt) inside the
# create/construc/edit/update_observation/naming views/forms.
# [I've removed them, since I think I've obviated their need. -JPH 20071124]
#   what=(string)
#   what
#
# Name formating:
#   text_name               Plain text.  (uses name.search_name)
#   format_name             Textilized.  (uses name.observation_name)
#   unique_text_name        Same as above, with id added to make unique.
#   unique_format_name
#   [What and base_name were confusing and inconsistent. -JPH 20071123]
#
# Voting and preferences:
#   average_vote            Get the "average" vote for this naming...
#   average_confidence      ...converted to confidence level.
#   average_agreement       ...converted to agreement level.
#   user_voted?(user)       Has a given user voted on this naming?
#   users_vote(user)        Get a given user's vote on this naming.
#   calc_vote_table         Used by show_votes.rhtml
#   change_vote(user, val)  Change a user's vote for this naming.
#   is_owners_favorite?     Is this (one of) the owner's favorite(s)?
#   is_consensus?           Is this the community consensus?

class Naming < ActiveRecord::Base
  belongs_to :observation
  belongs_to :name
  belongs_to :user
  has_many   :naming_reasons,    :dependent => :destroy
  has_many   :votes,             :dependent => :destroy

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

  # Average all the votes.
  # Returns integer.  (Use Vote.confidence/agreement() to interpret.)
  def average_vote
    sum = 0
    num = 0
    for v in self.votes
      sum += v.value
      num += 1
    end
    return num > 0 ? sum / num : 0
  end

  def average_agreement
    return Vote.agreement(self.average_vote)
  end

  def average_confidence
    return Vote.confidence(self.average_vote)
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
        :value => val,
        :users => [],
      }
    end
    for v in self.votes
      str = v.agreement
      table[str][:num] += 1
      table[str][:users] << v.user
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
        vote.created = now
        vote.naming  = self
        vote.user    = user
      end
      vote.modified = now
      vote.value    = value
      vote.save
    end
    # Update consensus.
    self.observation.calc_consensus
    return true
  end

  # Has anyone voted on this?  We don't want people destroying or chaning
  # the name for namings that the community has voted on.
  # Returns true if no one has.
  def editable?
    for v in self.votes
      # return false if v.user_id != self.user_id
      return false if v.user_id != self.user_id and v.value > 20
    end
    return true
  end

  # Returns true for all namings that have received the highest positive vote
  # from the owner of the corresponding observation.
  def is_owners_favorite?
    obs = self.observation
    if obs
      owner = obs.user
      if owner
        votes = owner.votes.select {|v| v.naming.observation == obs}
        max = 0
        for vote in votes
          max = vote.value if vote.value > 50 && vote.value > max
        end
        if max > 50
          for vote in votes
            return true if vote.naming == self && vote.value == max
          end
        end
      end
    end
    return false
  end

  # If the community consensus clearly derives from a single naming, then this will
  # return true for that naming.  Otherwise it returns false for everything else.
  def is_consensus?
    self.observation.name == self.name
  end

  validates_presence_of :name, :observation, :user
end

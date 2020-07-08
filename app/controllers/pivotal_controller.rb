# frozen_string_literal: true

#
#  = Pivotal Controller
#
#  Just controls one or two javascripty pages to interface with Pivotal
#  Tracker.  We want to give the general public easy access to Pivotal to allow
#  them to see, vote on, discuss, and propose new stories.  It makes use of the
#  Pivotal API to grab and update stories.
#
#  Note: Our database is not involved at all, to keep this as simple and
#  independent as possible.
#
#  == Votes
#
#  I'm recording votes via special machine-encoded lines at the end of each
#  story.  They're of the form:
#
#    VOTE: user_id [extra data]
#
#  At first, it'll be just a boolean flag -- either a user has voted for
#  something or not.  But I want to make room for the possibility of expanding
#  this to some sort of prioritization -- vote strongly or weakly for various
#  issues, say, or attach a short note.
#
################################################################################

class PivotalController < ApplicationController
  require_dependency "pivotal"

  def index
    @stories = if MO.pivotal_enabled
                 Pivotal.get_stories.sort_by(&:story_order)
               else
                 []
               end
  end
end

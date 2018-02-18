#
#  = Image Vote Model
#
#  Model describing a single vote for a single Image.  Most of the time views and
#  actions will use methods in Image to query and modify image votes.  See:
#
#  Image#vote_cache::   Average vote for this Image.
#  Image#users_vote::   Return a given User's ImageVote for this Image.
#  Image#change_vote::  Change a given User's ImageVote for this Image.
#  Image#image_votes::  Return list of all ImageVotes for this Image.
#
#  == Attributes
#
#  id::                 Locally unique numerical id, starting at 1, never used.
#  image_id::           Associated Image.
#  user_id::            Associated User.
#  value::              Value of Vote: 1, 2, 3 or 4.
#  anonymous::          Boolean: show this user's name?
#
#  == Callbacks
#
#  None.
#
################################################################################

class ImageVote < AbstractModel
  belongs_to :user
  belongs_to :image
end

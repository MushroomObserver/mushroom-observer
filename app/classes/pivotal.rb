class Pivotal
  require_dependency "pivotal/http"    # Deals with HTTP requests.
  require_dependency "pivotal/story"   # Encapsulates a single story.
  require_dependency "pivotal/comment" # Encapsulates a comment on a story.
  require_dependency "pivotal/vote"    # Encapsulates a vote for a story.
  require_dependency "pivotal/user"    # Encapsulates a user for a story
                                       # or comment.
end

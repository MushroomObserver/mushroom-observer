# encoding: utf-8
class Pivotal
  require_dependency 'pivotal/http'       # Deals with HTTP requests.
  require_dependency 'pivotal/story'      # Class encapsulating a single story.
  require_dependency 'pivotal/vote'       # Class encapsulating a vote for a story.
  require_dependency 'pivotal/comment'    # Class encapsulating a comment on a story.
end

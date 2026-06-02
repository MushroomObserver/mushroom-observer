# frozen_string_literal: true

# "Make this RSS-type filter the default" link. The path carries the
# current Query (q_param) and `make_default=1` so the controller can
# persist the user's preference. Caller passes the resolved path
# string because Tab POROs don't have request context to compute
# `add_q_param` themselves.
class Tab::RssLog::MakeDefault < Tab::Base
  def initialize(path:)
    super()
    @path = path
  end

  def title
    :rss_make_default.t
  end

  attr_reader :path
end

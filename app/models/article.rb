# News Articles
#
# == Attributes
#
#  name::               headline
#  id::                 unique numerical id (starting at 1)
#  rss_log_id::         unique numerical id
#  created_at::         Date/time it was first created.
#  updated_at::         Date/time it was last updated.
#  user::               user who created article
#
# == methods
#  display_name::       name boldfaced for display
#  author::             user.name and login for display
#
class Article < AbstractModel
  belongs_to :user
  belongs_to :rss_log

  # Automatically log standard events.
  self.autolog_events = [:created_at!, :updated_at!, :destroyed!]

  # name boldfaced (in Textile). Used by show and index templates
  def display_name
    "**#{name}**"
  end

  def format_name
    name
  end

  def unique_format_name
    name + " (#{id || "?"})"
  end

  # Article creator. Used by show and index templates
  def author
    "#{user.name} (#{user.login})"
  end
end

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
#  author::             user.name + user.login
#  display_name::       name boldfaced
#  format_name          name
#  unique_format_name   name + id
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

  # Article creator. Used by show and index templates
  def author
    "#{user.name} (#{user.login})"
  end

  # used by MatrixBoxPresenter to show orphaned obects
  def format_name
    name
  end

  # title + id
  # used by MatrixBoxPresenter to show unorphaned obects
  def unique_format_name
    name + " (#{id || "?"})"
  end
end

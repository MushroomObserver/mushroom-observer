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

  # name boldfaced (in Textile) for display
  def display_name
    "**#{name}**"
  end

  def author
    "#{user.name} (#{user.login})"
  end
end

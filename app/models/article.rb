# News Articles
class Article < AbstractModel
  belongs_to :user
  belongs_to :rss_log
end

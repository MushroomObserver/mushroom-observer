# encoding: utf-8
# helpers for show Article view
module ShowArticleHelper
  # Headline: (News Article 5)
  # displays Headline in bold
  def show_article_title(article)
    capture do
      concat(article.display_name.t)
      concat(": (#{:ARTICLE.t} #{article.id || "?"})")
    end
  end
end

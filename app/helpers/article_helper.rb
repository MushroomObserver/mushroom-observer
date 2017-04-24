# helpers for show Article views
module ArticleHelper
  # Headline: (News Article 5)
  # displays Headline in bold
  def show_article_title(article)
    capture do
      concat(article.display_name.t)
      concat(": (#{:ARTICLE.t} #{article.id || "?"})")
    end
  end

  def show_article_tabs
   tabs = [link_to(:article_index.t, action: :index)]
   return tabs unless permitted?
   tabs.push(link_to(:create_article.t, action: :create_article),
             link_to(:edit_article.t, action: :edit_article, id: @article.id)
            )
  end
end

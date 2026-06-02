# frozen_string_literal: true

# "Articles index" link.
class Tab::Article::Index < Tab::Base
  def title
    :index_article.t
  end

  def path
    articles_path
  end

  def model
    Article
  end
end

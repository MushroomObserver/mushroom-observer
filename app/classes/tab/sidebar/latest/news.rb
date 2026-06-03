# frozen_string_literal: true

# Sidebar latest nav: news (articles index).
class Tab::Sidebar::Latest::News < Tab::Base
  def title
    :NEWS.t
  end

  def path
    articles_path
  end

  def html_options
    { id: "nav_articles_link" }
  end
end

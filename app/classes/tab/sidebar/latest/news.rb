# frozen_string_literal: true

# Sidebar latest nav: news (articles index).
class Tab::Sidebar::Latest::News < Tab::Base
  def title
    :news.ti
  end

  def path
    articles_path
  end
end

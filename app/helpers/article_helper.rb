# frozen_string_literal: true

# Custom View Helpers for Article views
#
#   xx_tabs::      List of links to display in xx tabset; include links which
#                  write Articles only if user has write permission
#   xx_title::     Title of x page; includes any markup
#
module ArticleHelper
  def index_tabs
    return [] unless permitted?

    [link_to(:create_article_title.t, action: :create_article)]
  end

  def show_article_tabs
    tabs = [link_to(:index_article.t, action: :index_article)]
    return tabs unless permitted?

    tabs.push(link_to(:create_article_title.t, action: :create_article),
              link_to(:EDIT.t, action: :edit_article, id: @article.id),
              link_to(:DESTROY.t, action: :destroy_article, id: @article.id))
  end

  # "Title (#nnn)" textilized
  def show_article_title(article)
    capture do
      concat(article.display_title.t)
      concat(" (##{article.id || "?"})")
    end
  end

  # "Editing: Title (#nnn)"  textilized
  def edit_article_title(article)
    capture do
      concat("#{:EDITING.l}: ")
      concat(show_article_title(article))
    end
  end
end

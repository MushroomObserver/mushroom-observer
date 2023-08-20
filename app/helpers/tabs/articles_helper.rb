# frozen_string_literal: true

# Custom View Helpers for Article views
#
#   xx_tabs::      List of links to display in xx tabset; include links which
#                  write Articles only if user has write permission
#   xx_title::     Title of x page; includes any markup
#
module Tabs
  module ArticlesHelper
    def articles_index_links(user:)
      return [] unless Article.can_edit?(user)

      [new_article_link]
    end

    def articles_index_sorts
      [
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t],
        ["user",        :sort_by_user.t],
        ["title",       :sort_by_title.t]
      ].freeze
    end

    def article_show_links(article:, user:)
      links = [articles_index_link]
      # Can user modify all articles
      return links unless Article.can_edit?(user)

      links.push(new_article_link,
                 edit_article_link(article),
                 destroy_article_link(article))
    end

    def article_form_new_links
      [articles_index_link]
    end

    def article_form_edit_links(article:)
      [
        object_return_link(article),
        articles_index_link
      ]
    end

    def new_article_link
      [:create_article_title.t, new_article_path,
       { class: __method__.to_s }]
    end

    def edit_article_link(article)
      [:EDIT.t, edit_article_path(article.id),
       { class: __method__.to_s }]
    end

    def destroy_article_link(article)
      [nil, article, { button: :destroy }]
    end

    def articles_index_link
      [:index_article.t, articles_path, { class: __method__.to_s }]
    end

    # "Title (#nnn)" textilized
    def show_title(article)
      capture do
        concat(article.display_title.t)
        concat(" (##{article.id || "?"})")
      end
    end

    # "Editing: Title (#nnn)"  textilized
    def edit_title(article)
      capture do
        concat("#{:EDITING.l}: ")
        concat(show_title(article))
      end
    end
  end
end

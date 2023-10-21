# frozen_string_literal: true

# Custom View Helpers for Article views
#
#   xx_tabs::      List of links to display in xx tabset; include links which
#                  write Articles only if user has write permission
#   xx_title::     Title of x page; includes any markup
#
module Tabs
  module ArticlesHelper
    def articles_index_tabs(user:)
      return [] unless Article.can_edit?(user)

      [new_article_tab]
    end

    def articles_index_sorts
      [
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t],
        ["user",        :sort_by_user.t],
        ["title",       :sort_by_title.t]
      ].freeze
    end

    def article_show_tabs(article:, user:)
      links = [articles_index_tab]
      # Can user modify all articles
      return links unless Article.can_edit?(user)

      links.push(new_article_tab,
                 edit_article_tab(article),
                 destroy_article_tab(article))
    end

    def article_form_new_tabs
      [articles_index_tab]
    end

    def article_form_edit_tabs(article:)
      [
        object_return_tab(article),
        articles_index_tab
      ]
    end

    def new_article_tab
      [:create_article_title.t, new_article_path,
       { class: tab_id(__method__.to_s) }]
    end

    def edit_article_tab(article)
      [:EDIT.t, edit_article_path(article.id),
       { class: tab_id(__method__.to_s) }]
    end

    def destroy_article_tab(article)
      [nil, article, { button: :destroy }]
    end

    def articles_index_tab
      [:index_article.t, articles_path, { class: tab_id(__method__.to_s) }]
    end

    # "Title (#nnn)" textilized
    def article_show_title(article)
      capture do
        concat(article.display_title.t)
        concat(" (##{article.id || "?"})")
      end
    end

    # "Editing: Title (#nnn)"  textilized
    def article_edit_title(article)
      capture do
        concat("#{:EDITING.l}: ")
        concat(article_show_title(article))
      end
    end
  end
end

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
      InternalLink::Model.new(:create_article_title.t, Article,
                              new_article_path).tab
    end

    def edit_article_tab(article)
      InternalLink::Model.new(:EDIT.t, article,
                              edit_article_path(article.id)).tab
    end

    def destroy_article_tab(article)
      InternalLink::Model.new(
        :destroy_object.t(TYPE: Article), article, article,
        html_options: { button: :destroy }
      ).tab
    end

    def articles_index_tab
      InternalLink::Model.new(:index_article.t, Article, articles_path).tab
    end

    # "Title (#nnn)" textilized
    def article_show_title(article)
      capture do
        concat(article.display_title.t)
        concat(tag.span(article.id || "?", class: "badge badge-outline ml-3"))
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

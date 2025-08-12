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
      InternalLink::Model.new(
        new_page_title(:create_object, :ARTICLE), Article,
        new_article_path
      ).tab
    end

    def articles_index_tab
      InternalLink::Model.new(:index_article.t, Article, articles_path).tab
    end
  end
end

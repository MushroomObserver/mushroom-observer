# frozen_string_literal: true

module Views::Controllers::Articles
  class Index
    # One row of the articles index. Renders the inner contents of a
    # `Components::ListGroup::Item` (title link + byline + truncated
    # body teaser).
    class ArticleItem < Views::Base
      prop :article, ::Article

      def view_template
        div do
          link_to(@article.title.t, article_path(@article),
                  class: "text-larger")
        end
        div { render_byline }
        trusted_html(truncate(strip_tags(@article.body), length: 80).tpl)
      end

      private

      def render_byline
        small { plain("#{@article.created_at.web_time}:") }
        whitespace
        Link(type: :user, user: @article.user)
      end
    end
  end
end

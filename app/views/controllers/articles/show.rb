# frozen_string_literal: true

module Views::Controllers::Articles
  # Show-article page. Renders the byline (author + creation time),
  # the article body inside a Panel, and the standard versions
  # footer.
  class Show < Views::FullPageBase
    prop :article, ::Article

    def view_template
      container_class(:wide)
      add_show_title(@article)
      add_edit_icons(@article, current_user)

      render_byline
      render_body_panel
      render(::Views::Layouts::ObjectFooter.new(
               user: current_user, obj: @article
             ))
    end

    private

    def render_byline
      ContentPadded do
        plain(:by.ti)
        whitespace
        Link(type: :user, user: @article.user)
        plain(", ")
        small { plain(@article.created_at.display_time) }
      end
    end

    def render_body_panel
      Panel(panel_class: "mt-3",
            panel_id: "article_body") do |panel|
        panel.with_body { trusted_html(@article.body.tpl) }
      end
    end
  end
end

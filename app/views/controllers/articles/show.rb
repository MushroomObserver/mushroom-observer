# frozen_string_literal: true

module Views::Controllers::Articles
  # Show-article page. Renders the byline (author + creation time),
  # the article body inside a Panel, and the standard versions
  # footer. Converted from `articles/show.html.erb`.
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
      render(::Components::ContentPadded.new) do
        plain(:BY.t)
        plain(" ")
        render(::Components::Link::Object::User.new(user: @article.user))
        plain(", ")
        small { plain(@article.created_at.display_time) }
      end
    end

    def render_body_panel
      render(::Components::Panel.new(panel_class: "mt-3",
                                     panel_id: "article_body")) do |panel|
        panel.with_body { trusted_html(@article.body.tpl) }
      end
    end
  end
end

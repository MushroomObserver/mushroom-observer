# frozen_string_literal: true

module Views::Controllers::Articles
  # Form for creating or editing articles. Rendered directly by the
  # articles controller's `new.rb` and `edit.rb`.
  # Articles support Textile markup for formatting.
  class Form < ::Components::ApplicationForm
    def view_template
      super do
        render_title_field
        render_body_field
        submit(:SUBMIT.t, center: true)
      end
    end

    private

    def render_title_field
      text_field(:title, label: "#{:article_title.t}:",
                         data: { autofocus: true }) do |field_component|
        field_component.with_append do
          render(Components::Help::Block.new) do
            trusted_html(
              [:form_article_title_help.t,
               :field_textile_link.t].safe_join(" ")
            )
          end
        end
      end
    end

    def render_body_field
      textarea_field(:body, label: "#{:article_body.t}:",
                            rows: 10) do |field_component|
        field_component.with_append do
          render(Components::Help::Block.new) do
            trusted_html(:field_textile_link.t)
          end
        end
      end
    end
  end
end

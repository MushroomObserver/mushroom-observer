# frozen_string_literal: true

# Form for creating or editing articles.
# Articles support Textile markup for formatting.
class Components::ArticleForm < Components::ApplicationForm
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
        help_block do
          "#{:form_article_title_help.t} #{:field_textile_link.t}"
        end
      end
    end
  end

  def render_body_field
    textarea_field(:body, label: "#{:article_body.t}:",
                          rows: 10) do |field_component|
      field_component.with_append do
        help_block do
          :field_textile_link.t
        end
      end
    end
  end

  def help_block
    div(class: "help-block") { raw(yield.html_safe) } # rubocop:disable Rails/OutputSafety
  end
end

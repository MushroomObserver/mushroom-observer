# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Articles
  class FormTest < ComponentTestCase
    def setup
      super
      @article = Article.new
      @html = render_form
    end

    def test_renders_title_field_with_label_and_autofocus
      assert_html(@html, "label[for='article_title']", text: :article_title.l)
      assert_html(@html, "input[name='article[title]'][data-autofocus]")
    end

    def test_renders_body_field_with_label_and_rows
      assert_html(@html, "label[for='article_body']", text: :article_body.l)
      assert_html(@html, "textarea[name='article[body]'][rows='10']")
    end

    def test_renders_textile_help_for_title_and_body
      assert_html(@html, ".help-block",
                  text: :form_article_title_help.tp.as_displayed)
      assert_html(@html, ".help-block",
                  text: :field_textile_link.tp.as_displayed)
    end

    def test_renders_submit_button_centered
      assert_html(@html, "button[type='submit']", text: :submit.ti)
      assert_html(@html, ".center-block")
    end

    private

    def render_form
      render(Form.new(@article,
                      action: "/test_action",
                      id: "article_form"))
    end
  end
end

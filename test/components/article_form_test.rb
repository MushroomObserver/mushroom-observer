# frozen_string_literal: true

require "test_helper"

class ArticleFormTest < ComponentTestCase
  def setup
    super
    @article = Article.new
    @html = render_form
  end

  def test_renders_form_with_title_field
    assert_html(@html, "body", text: :article_title.l)
    assert_html(@html, "input[name='article[title]']")
    assert_html(@html, "input[data-autofocus]")
  end

  def test_renders_form_with_body_field
    assert_html(@html, "body", text: :article_body.l)
    assert_html(@html, "textarea[name='article[body]']")
    assert_html(@html, "textarea[rows='10']")
  end

  def test_renders_textile_help_for_title
    assert_html(@html, "body", text: :form_article_title_help.tp.as_displayed)
    assert_html(@html, "body", text: :field_textile_link.tp.as_displayed)
  end

  def test_renders_textile_help_for_body
    assert_html(@html, "body", text: :field_textile_link.tp.as_displayed)
  end

  def test_renders_submit_button
    assert_html(@html, "input[type='submit'][value='#{:SUBMIT.t}']")
    assert_html(@html, ".center-block")
  end

  private

  def render_form
    form = Components::ArticleForm.new(
      @article,
      action: "/test_action",
      id: "article_form"
    )
    render(form)
  end
end

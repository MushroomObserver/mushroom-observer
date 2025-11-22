# frozen_string_literal: true

require "test_helper"

class ArticleFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @article = Article.new
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_title_field
    assert_includes(@html, :article_title.t)
    assert_html(@html, "input[name='article[title]']")
    assert_html(@html, "input[data-autofocus]")
  end

  def test_renders_form_with_body_field
    assert_includes(@html, :article_body.t)
    assert_html(@html, "textarea[name='article[body]']")
    assert_html(@html, "textarea[rows='10']")
  end

  def test_renders_textile_help_for_title
    assert_includes(@html, :form_article_title_help.t)
    assert_includes(@html, :field_textile_link.t)
  end

  def test_renders_textile_help_for_body
    assert_includes(@html, :field_textile_link.t)
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

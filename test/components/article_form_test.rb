# frozen_string_literal: true

require "test_helper"

class ArticleFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @article = Article.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_title_field
    form = render_form

    assert_includes(form, :article_title.t)
    assert_includes(form, 'name="article[title]"')
    assert_includes(form, "data-autofocus")
  end

  def test_renders_form_with_body_field
    form = render_form

    assert_includes(form, :article_body.t)
    assert_includes(form, 'name="article[body]"')
    assert_includes(form, "rows=\"10\"")
  end

  def test_renders_textile_help_for_title
    form = render_form

    assert_includes(form, :form_article_title_help.t)
    assert_includes(form, :field_textile_link.t)
  end

  def test_renders_textile_help_for_body
    form = render_form

    assert_includes(form, :field_textile_link.t)
  end

  def test_renders_submit_button
    form = render_form

    assert_includes(form, :SUBMIT.t)
    assert_includes(form, "center-block")
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

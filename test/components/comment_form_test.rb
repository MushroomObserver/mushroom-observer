# frozen_string_literal: true

require "test_helper"

class CommentFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @comment = Comment.new
    controller.request = ActionDispatch::TestRequest.create
    @html = render_form
  end

  def test_renders_form_with_summary_field
    assert_html(@html, "input[name='comment[summary]']")
    assert_html(@html, "input[data-autofocus]")
  end

  def test_renders_form_with_comment_field
    assert_html(@html, "textarea[name='comment[comment]']")
    assert_html(@html, "textarea[rows='10']")
  end

  def test_renders_submit_button_for_new_record
    assert_html(@html, "input[type='submit'][value='#{:CREATE.l}']")
    assert_html(@html, "input.btn.btn-default")
  end

  def test_enables_turbo_by_default
    assert_html(@html, "form[data-turbo='true']")
  end

  def test_renders_submit_button_for_existing_record
    @comment = comments(:minimal_unknown_obs_comment_1)
    html = render_form

    assert_html(html, "input[type='submit'][value='#{:SAVE_EDITS.l}']")
  end

  def test_omits_turbo_when_local_true
    html = render_form_local
    doc = Nokogiri::HTML(html)

    assert_nil(doc.at_css("form[data-turbo]"))
  end

  def test_auto_determines_url_for_new_comment
    @comment.target_id = 123
    @comment.target_type = "Observation"
    html = render_form_without_action

    assert_html(html, "form[action='/comments?target=123&type=Observation']")
  end

  def test_auto_determines_url_for_existing_comment
    @comment = comments(:minimal_unknown_obs_comment_1)
    html = render_form_without_action

    assert_html(html, "form[action='/comments/#{@comment.id}']")
  end

  private

  def render_form
    form = Components::CommentForm.new(
      @comment,
      action: "/test_action",
      id: "comment_form",
      local: false
    )
    render(form)
  end

  def render_form_local
    form = Components::CommentForm.new(
      @comment,
      action: "/test_action",
      id: "comment_form",
      local: true
    )
    render(form)
  end

  def render_form_without_action
    form = Components::CommentForm.new(@comment)
    render(form)
  end
end

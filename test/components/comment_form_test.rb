# frozen_string_literal: true

require "test_helper"

class CommentFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @comment = Comment.new
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_summary_field
    form = render_form

    assert_includes(form, :form_comments_summary.t)
    assert_includes(form, 'name="comment[summary]"')
    assert_includes(form, "data-autofocus")
  end

  def test_renders_form_with_comment_field
    form = render_form

    assert_includes(form, :form_comments_comment.t)
    assert_includes(form, 'name="comment[comment]"')
    assert_includes(form, "rows=\"10\"")
  end

  def test_renders_submit_button_for_new_record
    form = render_form

    assert_includes(form, :CREATE.l)
    assert_includes(form, "btn btn-default")
    assert_includes(form, "center-block my-3")
  end

  def test_renders_submit_button_for_existing_record
    @comment = comments(:minimal_unknown_obs_comment_1)
    form = render_form

    assert_includes(form, :SAVE_EDITS.l)
  end

  def test_enables_turbo_by_default
    form = render_form

    assert_match(/<form[^>]*\sdata-turbo[>\s]/, form)
  end

  def test_omits_turbo_when_local_true
    form = render_form_local

    assert_no_match(/<form[^>]*\sdata-turbo/, form)
  end

  def test_auto_determines_url_for_new_comment
    @comment.target_id = 123
    @comment.target_type = "Observation"
    form = render_form_without_action

    assert_includes(form, 'action="/comments?target=123&type=Observation"')
  end

  def test_auto_determines_url_for_existing_comment
    @comment = comments(:minimal_unknown_obs_comment_1)
    form = render_form_without_action

    assert_includes(form, "action=\"/comments/#{@comment.id}\"")
  end

  private

  def render_form
    form = Components::CommentForm.new(
      @comment,
      action: "/test_action",
      id: "comment_form"
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

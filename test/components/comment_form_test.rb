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

  private

  def render_form
    form = Components::CommentForm.new(
      @comment,
      action: "/test_action",
      id: "comment_form"
    )
    render(form)
  end
end

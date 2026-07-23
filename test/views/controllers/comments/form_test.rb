# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Comments
  class FormTest < ComponentTestCase
    def setup
      super
      @comment = Comment.new
      @html = render_form
    end

    def test_renders_form_with_summary_field
      assert_html(@html, "input[name='comment[summary]'][data-autofocus]")
    end

    def test_renders_form_with_comment_field
      assert_html(@html, "textarea[name='comment[comment]'][rows='10']")
    end

    def test_renders_submit_button_for_new_record
      assert_html(@html, "button[type='submit']", text: :create.ti)
    end

    def test_enables_turbo_by_default
      assert_html(@html, "form[data-turbo='true']")
    end

    def test_renders_submit_button_for_existing_record
      @comment = comments(:minimal_unknown_obs_comment_1)
      html = render_form

      assert_html(html, "button[type='submit']", text: :save_edits.ti)
    end

    def test_omits_turbo_when_local_true
      html = render_form_local

      assert_no_html(html, "form[data-turbo]")
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
      render(Form.new(@comment,
                      action: "/test_action",
                      id: "comment_form",
                      local: false))
    end

    def render_form_local
      render(Form.new(@comment,
                      action: "/test_action",
                      id: "comment_form",
                      local: true))
    end

    def render_form_without_action
      render(Form.new(@comment))
    end
  end
end

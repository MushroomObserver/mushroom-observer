# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Admin::Emails::MergeRequests
  class FormTest < ComponentTestCase
    def setup
      super
      @email = FormObject::EmailRequest.new
      @old_name = names(:coprinus_comatus)
      @new_name = names(:agaricus_campestris)
    end

    def test_renders_form_with_help_text
      html = render_form

      # `.tp` wraps the rendered text in
      # `<div class="textile">...</div>`; scope the selector there
      # (the outer `<p>` from `p { :foo.tp }` only contains the
      # textile div, not direct text).
      assert_html(html, ".textile",
                  text: :email_merge_request_help.tp(
                    type: Name.type_tag
                  ).as_displayed)
    end

    def test_renders_old_object_field
      html = render_form

      assert_includes(html, :NAME.l)
      assert_includes(html, @old_name.unique_format_name.t)
    end

    def test_renders_new_object_field
      html = render_form

      assert_includes(html, @new_name.unique_format_name.t)
    end

    def test_renders_message_field
      html = render_form

      assert_html(html, "label[for='email_message']",
                  text: :Notes.l)
      assert_html(html,
                  "textarea[name='email[message]'][rows='10']" \
                  "[data-autofocus]")
    end

    def test_renders_submit_button
      html = render_form

      assert_html(html, "input[type='submit'][value='#{:SEND.l}']")
      assert_html(html, ".center-block")
    end

    private

    def render_form
      form = Form.new(@email,
                      old_obj: @old_name,
                      new_obj: @new_name,
                      model_class: Name)
      # Stub url_for to avoid routing errors in test environment
      form.stub(:url_for, "/test_action") do
        render(form)
      end
    end
  end
end

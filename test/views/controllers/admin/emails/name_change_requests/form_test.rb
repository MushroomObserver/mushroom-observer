# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Admin::Emails::NameChangeRequests
  class FormTest < ComponentTestCase
    def setup
      super
      @email = FormObject::EmailRequest.new
      @name = names(:coprinus_comatus)
      @new_name = "Agaricus foo"
      @new_name_with_icn_id = "#{@new_name}[#123456]"
    end

    def test_renders_form_with_help_text
      html = render_form

      # `.tp` wraps the rendered text in
      # `<div class="textile">...</div>`; scope the selector there
      # (the outer `<p>` from `p { :foo.tp }` only contains the
      # textile div, not direct text).
      assert_html(html, ".textile",
                  text: :email_name_change_request_help.tp.as_displayed)
    end

    def test_renders_current_name_field
      html = render_form
      value = "#{@name.unique_search_name}[##{@name.icn_id}]"

      assert_html(html, "label[for='email_name']", text: "#{:NAME.l}:")
      assert_html(html, "label[for='email_name'] + p.form-control-static",
                  text: value)
    end

    def test_renders_new_name_hidden_field
      html = render_form

      assert_html(html, "label[for='email_new_name_with_icn_id']",
                  text: "#{:new_name.l}:")
      assert_html(html, "label[for='email_new_name_with_icn_id'] " \
                        "+ p.form-control-static",
                  text: @new_name_with_icn_id)
      assert_html(html,
                  "input[type='hidden']" \
                  "[name='email[new_name_with_icn_id]']")
    end

    def test_renders_message_field
      html = render_form

      assert_html(html, "label[for='email_message']", text: :Notes.l)
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
                      name: @name,
                      new_name: @new_name,
                      new_name_with_icn_id: @new_name_with_icn_id)
      # Stub url_for to avoid routing errors in test environment
      form.stub(:url_for, "/test_action") do
        render(form)
      end
    end
  end
end

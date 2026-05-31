# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Admin::Donations
  class FormTest < ComponentTestCase
    def setup
      super
      @donation = Donation.new
      @html = render_form
    end

    def test_renders_form_with_amount_field
      assert_html(@html, "label[for='donation_amount']",
                  text: :confirm_amount.l)
      assert_html(@html,
                  "input[name='donation[amount]'][size='7']")
    end

    def test_renders_form_with_who_field
      assert_html(@html, "label[for='donation_who']",
                  text: :WHO.l)
      assert_html(@html,
                  "input[name='donation[who]'][size='50']")
    end

    def test_renders_form_with_anonymous_checkbox
      assert_html(@html, "label[for='donation_anonymous']",
                  text: :donate_anonymous.l)
      assert_html(@html,
                  "input[name='donation[anonymous]'][type='checkbox']")
    end

    def test_renders_form_with_email_field
      assert_html(@html, "label[for='donation_email']",
                  text: :EMAIL.l)
      assert_html(@html, "input[name='donation[email]']")
    end

    def test_renders_submit_button
      assert_html(@html,
                  "input[type='submit']" \
                  "[value='#{:create_donation_add.l}']")
      assert_html(@html, ".center-block")
    end

    private

    def render_form
      render(Form.new(@donation,
                      action: "/test_action",
                      id: "admin_donation_form"))
    end
  end
end

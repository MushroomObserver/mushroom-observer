# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Account::Verifications
  class ReverifyTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      User.current = nil
    end

    def test_renders_post_button_with_primary_style
      html = render_view

      path = routes.account_resend_verification_email_path(id: @user.id)
      assert_html(html, "form[action='#{path}'][data-turbo='true']")
      assert_html(html, "button#account_reverify_link.btn.btn-primary",
                  text: :reverify_link.t)
      assert_no_html(html, "form[data-turbo='true'] button.btn-default")
    end

    def test_raises_when_raw_btn_class_passed
      assert_raises(ArgumentError) do
        Components::Button::Post.new(
          name: :reverify_link.t,
          target: routes.account_resend_verification_email_path(id: @user.id),
          class: "btn btn-primary"
        )
      end
    end

    private

    def render_view
      render(Reverify.new(unverified_user: @user))
    end
  end
end

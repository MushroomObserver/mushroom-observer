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

    # Parity: `style: :primary` produces the same class as the old
    # `class: "btn btn-primary"` call on the base CrudButton.
    def test_variant_kwarg_parity_with_old_class_kwarg
      old_html = render(
        Components::CrudButton.new(
          name: :reverify_link.t,
          target: routes.account_resend_verification_email_path(id: @user.id),
          method: :post,
          class: "btn btn-primary",
          id: "account_reverify_link"
        )
      )
      new_html = render(
        Components::CrudButton::Post.new(
          name: :reverify_link.t,
          target: routes.account_resend_verification_email_path(id: @user.id),
          style: :primary,
          id: "account_reverify_link"
        )
      )

      assert_html_element_equivalent(
        "<div>#{old_html}</div>",
        "<div>#{new_html}</div>",
        selector: "div",
        label: "reverify_button"
      )
    end

    private

    def render_view
      render(Reverify.new(unverified_user: @user))
    end
  end
end

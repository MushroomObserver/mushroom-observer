# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Admin::Users
  class BonusesFormTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @user_stats = UserStats.find_or_create_by(user_id: @user.id)
      @user_stats.bonuses = [[10, "Test reason 1"], [20, "Test reason 2"],
                             [30, "Test reason 3"]]
      @html = render_form
    end

    def test_renders_form_with_help_text
      assert_html(@html, ".help-block")
    end

    def test_renders_form_with_val_textarea
      assert_html(@html,
                  "textarea[name='user_stats[val]'][rows='5']",
                  text: @user_stats.formatted_bonuses)
    end

    def test_renders_submit_button
      assert_html(@html,
                  "button[type='submit']", text: :save_edits.ti)
      assert_html(@html, ".center-block")
    end

    # `form_action` always calls `admin_user_path` (Superform's
    # `form_tag` evaluates it to build the `<form action=...>`
    # attribute even when an explicit `action:` override is also
    # passed) — the `rescue` only exists for environments where that
    # route helper isn't available. Stub it to raise to exercise the
    # fallback directly.
    def test_form_action_falls_back_when_admin_route_raises
      form = render_form_instance
      form.define_singleton_method(:admin_user_path) do |*|
        raise(NoMethodError)
      end

      assert_equal("/admin/users/#{@user_stats.user_id}", form.form_action)
    end

    private

    def render_form_instance
      BonusesForm.new(@user_stats, action: "/test_action",
                                   id: "user_bonuses_form")
    end

    def render_form
      render(render_form_instance)
    end
  end
end

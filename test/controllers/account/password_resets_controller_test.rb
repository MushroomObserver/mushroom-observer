# frozen_string_literal: true

require("test_helper")

module Account
  class PasswordResetsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def test_new
      get(:new)

      assert_response(:success)
      assert_head_title(:email_new_password_title.l)
    end

    def test_create_user_not_found
      post(:create, params: { new_user: {
             login: "brandnewuser",
             password: "brandnewpassword",
             password_confirmation: "brandnewpassword",
             name: "brand new name"
           } })

      assert_unprocessable
      assert_flash_error(
        on_fail: "create should flash error if user doesn't already exist"
      )
      assert_select("form#account_password_reset_form")
    end

    def test_create_success
      user = users(:roy)
      old_password = user.password

      assert_enqueued_with(
        job: ActionMailer::MailDeliveryJob,
        args: lambda { |args|
          args[0] == "PasswordMailer" &&
            args[1] == "build" &&
            args[3][:args][0][:receiver] == user &&
            args[3][:args][0][:password].is_a?(String)
        }
      ) do
        post(:create, params: { new_user: { login: user.login } })
      end

      assert_redirected_to(new_account_login_path)
      user.reload
      assert_not_equal(user.password, old_password,
                       "New password should be different from old")
    end

    # `@new_user.save` failing used to fall through with no render or
    # redirect at all -- a real request would raise, since there's no
    # ERB fallback template in this Phlex-only app (found via Copilot
    # review on #5058). Force the failure by stubbing `save` on the
    # looked-up user, routed through a real request so the response
    # itself (not just a directly-invoked private method) proves the
    # fix.
    def test_create_save_failure
      user = users(:roy)
      # `update_attribute` (called internally by `change_password`)
      # calls `save(validate: false)` -- accept and ignore args so
      # both that call and the controller's own `@new_user.save`
      # hit this stub.
      user.define_singleton_method(:save) { |*_args| false }

      User.stub(:where, ->(*_args) { [user] }) do
        assert_no_enqueued_jobs do
          post(:create, params: { new_user: { login: user.login } })
        end
      end

      assert_unprocessable
      assert_select("form#account_password_reset_form")
    end
  end
end

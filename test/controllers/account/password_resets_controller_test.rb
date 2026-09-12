# frozen_string_literal: true

require("test_helper")

module Account
  class PasswordResetsControllerTest < FunctionalTestCase
    include ActiveJob::TestHelper

    def test_new
      get(:new)

      assert_response(:success)
      assert_head_title(:email_new_password_title.l)
      assert_select("form#account_password_reset_form[data-turbo='true']")
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

    # A missing/blank `login` param used to build `User[:name].eq(nil)`
    # -> `name IS NULL` in the query, which could match an arbitrary
    # user who never set a display name (`users.name` has no NOT NULL
    # constraint), silently resetting a stranger's password (Copilot
    # review on #5072). Create a user with a nil name so this test
    # would have matched them before the `login.blank?` guard.
    def test_create_blank_login_does_not_match_nil_name_user
      nameless_user = User.create!(login: "nameless_login_user",
                                   email: "nameless_login_user@example.com")
      assert_nil(nameless_user.name)
      old_password = nameless_user.password

      assert_no_enqueued_jobs do
        post(:create, params: { new_user: { login: "" } })
      end

      assert_unprocessable
      assert_flash_error
      nameless_user.reload
      assert_equal(old_password, nameless_user.password,
                   "Blank login should not match the nameless user")
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

    # A failing password change used to fall through with no render or
    # redirect at all -- a real request would raise, since there's no
    # ERB fallback template in this Phlex-only app (found via Copilot
    # review on #5058). Force the failure by stubbing `save` on the
    # looked-up user, routed through a real request so the response
    # itself (not just a directly-invoked private method) proves the
    # fix.
    def test_create_save_failure
      user = users(:roy)
      # `change_password` calls `update_attribute`, which calls
      # `save(validate: false)` -- accept and ignore args so that
      # call hits this stub.
      user.define_singleton_method(:save) { |*_args| false }

      User.stub(:find_by, ->(*_args) { user }) do
        assert_no_enqueued_jobs do
          post(:create, params: { new_user: { login: user.login } })
        end
      end

      assert_unprocessable
      assert_select("form#account_password_reset_form")
    end
  end
end

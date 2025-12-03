# frozen_string_literal: true

require("test_helper")

module Admin
  module Emails
    class FeaturesControllerTest < FunctionalTestCase
      include ActiveJob::TestHelper

      def test_features
        page = :create
        params = { feature_email: { content: "test" } }

        logout
        post(page, params: params)
        assert_redirected_to(new_account_login_path)

        login("rolf")
        post(page, params: params)
        assert_redirected_to("/")
        assert_flash_text(/denied|only.*admin/i)

        make_admin("rolf")
        assert_enqueued_with(
          job: ActionMailer::MailDeliveryJob,
          args: ->(args) { args[0] == "FeaturesMailer" && args[1] == "build" }
        ) do
          post(page, params: params)
        end
        assert_redirected_to(users_path(by: "name"))
      end

      def test_features_requires_content
        login("rolf")
        make_admin("rolf")

        assert_no_enqueued_jobs do
          post(:create, params: { feature_email: { content: "" } })
        end
        assert_flash_error
        assert_template(:new)
      end
    end
  end
end

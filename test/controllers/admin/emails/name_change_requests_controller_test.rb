# frozen_string_literal: true

require("test_helper")

module Admin
  module Emails
    class NameChangeRequestsControllerTest < FunctionalTestCase
      include ActiveJob::TestHelper

      def test_email_name_change_request_not_logged_in
        name = names(:lactarius)
        params = {
          name_id: name.id,
          new_name_with_icn_id: "#{name.search_name} [#777]"
        }

        get(:new, params: params)
        assert_response(:redirect)
      end

      def test_email_name_change_request_get
        name = names(:lactarius)
        assert(name.icn_id, "Test needs a fixture with an icn_id")
        assert(name.dependents?, "Test needs a fixture with dependents")
        params = {
          name_id: name.id,
          new_name_with_icn_id: "#{name.search_name} [#777]"
        }
        login("mary")

        get(:new, params: params)
        assert_select(
          "#title", text: :email_name_change_request_title.l, count: 1
        )
      end

      def test_email_name_change_request_turbo_stream
        name = names(:lactarius)
        params = {
          name_id: name.id,
          new_name_with_icn_id: "#{name.search_name} [#777]"
        }
        login("mary")

        get(:new, params: params, format: :turbo_stream)
        assert_response(:success)
      end

      def test_email_name_change_request_missing_name
        login("mary")
        params = {
          name_id: -999,
          new_name_with_icn_id: "Whatever [#777]"
        }

        get(:new, params: params)
        assert_response(:redirect)
      end

      def test_email_name_change_request_same_icn_id
        name = names(:lactarius)
        # Using the same icn_id should fail check_different_icn_ids
        same_name_with_icn_id = "#{name.search_name} [##{name.icn_id}]"
        params = {
          name_id: name.id,
          new_name_with_icn_id: same_name_with_icn_id
        }
        login("mary")

        get(:new, params: params)
        assert_response(:redirect)
      end

      def test_email_name_change_request_post
        name = names(:lactarius)
        assert(name.icn_id, "Test needs a fixture with an icn_id")
        assert(name.dependents?, "Test needs a fixture with dependents")
        params = {
          name_id: name.id,
          new_name_with_icn_id: "#{name.search_name} [#777]"
        }
        login("mary")

        post(:create, params: params)
        assert_redirected_to(
          name_path(id: name.id),
          "Sending Name Change Request should redirect to Name page"
        )
      end

      def test_email_name_change_request_post_delivers_email
        name = names(:lactarius)
        params = {
          name_id: name.id,
          new_name_with_icn_id: "#{name.search_name} [#777]",
          email: { message: "Please change this" }
        }
        login("mary")
        email_count = ActionMailer::Base.deliveries.count

        perform_enqueued_jobs do
          post(:create, params: params)
        end

        assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
        assert_match(/Please change this/,
                     ActionMailer::Base.deliveries.last.to_s)
      end

      def test_email_name_change_request_post_missing_name
        login("mary")
        params = {
          name_id: -999,
          new_name_with_icn_id: "Whatever [#777]"
        }

        post(:create, params: params)
        assert_response(:redirect)
      end

      def test_email_name_change_request_post_same_icn_id
        name = names(:lactarius)
        same_name_with_icn_id = "#{name.search_name} [##{name.icn_id}]"
        params = {
          name_id: name.id,
          new_name_with_icn_id: same_name_with_icn_id
        }
        login("mary")

        post(:create, params: params)
        assert_response(:redirect)
      end
    end
  end
end

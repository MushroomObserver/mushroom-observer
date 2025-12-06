# frozen_string_literal: true

require("test_helper")

module Admin
  module Emails
    class MergeRequestsControllerTest < FunctionalTestCase
      include ActiveJob::TestHelper

      def test_email_merge_request
        name1 = Name.all.sample
        name2 = Name.all.sample
        params = {
          type: :Name,
          old_id: name1.id,
          new_id: name2.id
        }

        # Test 1: Not logged in - should redirect
        get(:new, params: params)
        assert_response(:redirect)

        # Test 2: Logged in but type param is nil - should show type error
        login("rolf")
        get(:new, params: params.except(:type))
        assert_response(:redirect)
        assert_flash_error(:runtime_invalid.t(type: '"type"', value: ""))

        # Test 3: Logged in but type param is invalid
        get(:new, params: params.merge(type: :Bogus))
        assert_response(:redirect)
        assert_flash_error(:runtime_invalid.t(type: '"type"', value: "Bogus"))

        # Test 4: Valid type but missing required params
        get(:new, params: params.except(:old_id))
        assert_response(:redirect)
        get(:new, params: params.except(:new_id))
        assert_response(:redirect)
        get(:new, params: params.merge(old_id: -123))
        assert_response(:redirect)
        get(:new, params: params.merge(new_id: -456))
        assert_response(:redirect)

        # Test 5: Valid request with all params - should succeed
        get(:new, params: params)
        assert_response(:success)
        assert_names_equal(name1, assigns(:old_obj))
        assert_names_equal(name2, assigns(:new_obj))
        url = "admin/emails/merge_requests"
        url += "?new_id=#{name2.id}&old_id=#{name1.id}&type=Name"
        assert_select("form[action*='#{url}']", count: 1)
      end

      def test_email_merge_request_post
        email_count = ActionMailer::Base.deliveries.count
        name1 = Name.all.sample
        name2 = Name.all.sample
        params = {
          type: :Name,
          old_id: name1.id,
          new_id: name2.id,
          merge_request: { notes: "SHAZAM" }
        }

        # Test 1: Not logged in - should redirect and not send email
        post(:create, params: params)
        assert_response(:redirect)
        assert_equal(email_count, ActionMailer::Base.deliveries.count)

        # Test 2: Logged in but type param is nil
        # Should show type error and not send email
        login("rolf")
        post(:create, params: params.except(:type))
        assert_response(:redirect)
        assert_flash_error(:runtime_invalid.t(type: '"type"', value: ""))
        assert_equal(email_count, ActionMailer::Base.deliveries.count)

        # Test 3: Logged in with invalid type
        # Should show type error and not send email
        post(:create, params: params.merge(type: :Bogus))
        assert_response(:redirect)
        assert_flash_error(:runtime_invalid.t(type: '"type"', value: "Bogus"))
        assert_equal(email_count, ActionMailer::Base.deliveries.count)

        # Test 4: Valid request - should send email
        perform_enqueued_jobs do
          post(:create, params: params)
        end
        assert_response(:redirect)
        assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
        assert_match(/SHAZAM/, ActionMailer::Base.deliveries.last.to_s)
      end

      def test_email_merge_request_turbo_stream
        login("rolf")
        name1 = names(:agaricus_campestris)
        name2 = names(:boletus_edulis)
        params = { type: :Name, old_id: name1.id, new_id: name2.id }

        get(:new, params: params, format: :turbo_stream)
        assert_response(:success)
      end

      def test_email_merge_request_with_invalid_objects
        login("rolf")
        name1 = names(:agaricus_campestris)
        params = {
          type: :Name,
          old_id: name1.id,
          new_id: -999,
          merge_request: { notes: "test" }
        }

        # Test create with invalid new_id redirects
        post(:create, params: params)
        assert_response(:redirect)
      end

      def test_email_merge_request_herbarium_type
        login("rolf")
        herb1 = herbaria(:nybg_herbarium)
        herb2 = herbaria(:fundis_herbarium)
        params = { type: :Herbarium, old_id: herb1.id, new_id: herb2.id }

        get(:new, params: params)
        assert_response(:success)
      end

      def test_email_merge_request_location_type
        login("rolf")
        loc1 = locations(:burbank)
        loc2 = locations(:albion)
        params = { type: :Location, old_id: loc1.id, new_id: loc2.id }

        get(:new, params: params)
        assert_response(:success)
      end
    end
  end
end

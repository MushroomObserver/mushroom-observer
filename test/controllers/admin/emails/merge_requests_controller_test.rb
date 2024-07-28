# frozen_string_literal: true

require("test_helper")

module Admin
  module Emails
    class MergeRequestsControllerTest < FunctionalTestCase
      def test_email_merge_request
        name1 = Name.all.sample
        name2 = Name.all.sample
        params = {
          type: :Name,
          old_id: name1.id,
          new_id: name2.id
        }

        get(:new, params: params)
        assert_response(:redirect)

        login("rolf")
        get(:new, params: params.except(:type))
        assert_response(:redirect)
        get(:new, params: params.except(:old_id))
        assert_response(:redirect)
        get(:new, params: params.except(:new_id))
        assert_response(:redirect)
        get(:new, params: params.merge(type: :Bogus))
        assert_response(:redirect)
        get(:new, params: params.merge(old_id: -123))
        assert_response(:redirect)
        get(:new, params: params.merge(new_id: -456))
        assert_response(:redirect)

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
          notes: "SHAZAM"
        }

        post(:create, params: params)
        assert_response(:redirect)
        assert_equal(email_count, ActionMailer::Base.deliveries.count)

        login("rolf")
        post(:create, params: params)
        assert_response(:redirect)
        assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
        assert_match(/SHAZAM/, ActionMailer::Base.deliveries.last.to_s)
      end
    end
  end
end

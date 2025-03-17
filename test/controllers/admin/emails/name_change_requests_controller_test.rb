# frozen_string_literal: true

require("test_helper")

module Admin
  module Emails
    class NameChangeRequestsControllerTest < FunctionalTestCase
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
    end
  end
end

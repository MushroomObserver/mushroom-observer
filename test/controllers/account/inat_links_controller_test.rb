# frozen_string_literal: true

require("test_helper")

module Account
  class InatLinksControllerTest < FunctionalTestCase
    include Inat::Constants

    def test_new_sends_the_user_to_inat_with_a_link_state
      login("rolf")

      get(:new)

      state = session[:inat_link_state]
      assert(state.start_with?(
               InatImportsController::AccountLinking::LINK_STATE_PREFIX
             ))
      assert_redirected_to("#{INAT_AUTHORIZATION_URL}&state=#{state}")
    end
  end
end

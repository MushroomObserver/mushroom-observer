# frozen_string_literal: true

require("test_helper")

module Admin
  class TurnOnControllerTest < FunctionalTestCase
    def test_turn_admin_on
      get(:show)
      assert_false(session[:admin])
      login(:rolf)
      get(:show)
      assert_false(session[:admin])
      rolf.admin = true
      rolf.save!
      get(:show)
      assert_true(session[:admin])

      # For convenience, just switch to the TurnOffController here
      # https://stackoverflow.com/questions/22725883/in-a-rails-controller-test-how-to-access-a-different-controller-action
      @controller = Admin::TurnOffController.new
      get(:show)
      assert_false(session[:admin])
    end
  end
end

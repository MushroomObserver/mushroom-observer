# frozen_string_literal: true

require("test_helper")

class AdminModeControllerTest < FunctionalTestCase
  def test_turn_admin_on_and_off
    get(:show, params: { turn_on: true })
    assert_false(session[:admin])
    login(:rolf)
    get(:show, params: { turn_on: true })
    assert_false(session[:admin])
    rolf.admin = true
    rolf.save!
    get(:show, params: { turn_on: true })
    assert_true(session[:admin])

    get(:show, params: { turn_off: true })
    assert_false(session[:admin])
  end
end

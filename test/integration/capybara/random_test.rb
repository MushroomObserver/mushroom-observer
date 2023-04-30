# frozen_string_literal: true

require("test_helper")

class RandomTest < CapybaraIntegrationTestCase
  def test_pivotal_tracker
    login(users(:zero_user))
    visit("/")
    click_link(text: "Feature Tracker")
    assert_selector("body.pivotal__index")
  end

  # Test "/controller/action/type/id" route used by AJAX controller.
  def test_ajax_router
    visit("/ajax/auto_complete/name/Agaricus")
    lines = page.html.split("\n")
    assert_equal("A", lines.first)
    assert(lines.include?("Agaricus"))
    assert(lines.include?("Agaricus campestris"))
  end

  def test_the_homepage
    login(users(:zero_user))
    visit("/")
    assert_selector("body.observations__index")
    assert_text("account")
  end

  def test_login_and_logout
    login!(rolf)

    visit("/info/how_to_help")
    assert_selector("body.info__how_to_help")
    assert_no_link(href: "/account/login/new")
    assert_link(href: "/account/logout")
    assert_link(href: "/users/#{rolf.id}")

    click_link(text: "Logout")
    assert_template("account/login/logout")
    assert_link(href: "/account/login/new")
    assert_no_link(href: "/account/logout")
    assert_no_link(href: "/users/#{rolf.id}")

    click_link(text: "Introduction")
    assert_template("info/intro")
    assert_link(href: "/account/login/new")
    assert_no_link(href: "/account/logout")
    assert_no_link(href: "/users/#{rolf.id}")
  end

  def test_sessions
    rolf_session = Capybara::Session.new(:rack_test, Rails.application)
    login(rolf, session: rolf_session)
    mary_session = Capybara::Session.new(:rack_test, Rails.application)
    login(mary, session: mary_session)
    katrina_session = Capybara::Session.new(:rack_test, Rails.application)
    login(katrina, session: katrina_session)

    rolf_session.visit("/info/intro")
    rolf_session.assert_text("rolf")
    rolf_session.assert_no_text("katrina")

    mary_session.visit("/info/intro")
    mary_session.assert_text("mary")
    mary_session.assert_no_text("rolf")

    katrina_session.visit("/info/intro")
    katrina_session.assert_text("katrina")
    katrina_session.assert_no_text("rolf") # mary too general
  end
end

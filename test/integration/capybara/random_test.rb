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
  end

  def test_login_and_logout
    login!(rolf)

    visit("/info/how_to_help")
    assert_selector("body.info__how_to_help")
    assert_no_link(href: "/account/login/new")
    assert_link(href: "/account/logout")
    assert_link(href: "/users/#{rolf.id}")

    first(:link, text: "Logout").click
    assert_selector("body.login__logout")
    assert_link(href: "/account/login/new")
    assert_no_link(href: "/account/logout")
    assert_no_link(href: "/users/#{rolf.id}")

    click_link(text: "Introduction")
    assert_selector("body.info__intro")
    assert_link(href: "/account/login/new")
    assert_no_link(href: "/account/logout")
    assert_no_link(href: "/users/#{rolf.id}")
  end

  def test_sessions
    rolf_session = open_session
    login(rolf, session: rolf_session)
    mary_session = open_session
    login(mary, session: mary_session)
    katrina_session = open_session
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

  # -------------------------------------------------------------------------
  #  Need integration test to make sure session and actions are all working
  #  together correctly.
  # -------------------------------------------------------------------------

  def test_thumbnail_maps
    visit("/#{observations(:minimal_unknown_obs).id}")
    assert_selector("body.observations__show")

    login("dick")
    assert_selector("body.observations__show")
    assert_selector("div.thumbnail-map")
    click_link(text: "Hide thumbnail map")
    assert_selector("body.observations__show")
    assert_no_selector("div.thumbnail-map")

    visit("/#{observations(:detailed_unknown_obs).id}")
    assert_selector("body.observations__show")
    assert_no_selector("div.thumbnail-map")
  end
end

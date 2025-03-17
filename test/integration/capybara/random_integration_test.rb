# frozen_string_literal: true

require "test_helper"

class RandomIntegrationTest < CapybaraIntegrationTestCase
  def test_the_homepage
    login(users(:zero_user))
    visit("/")
    assert_selector("body.observations__index")
  end

  def test_uptime_probe
    visit("/test")
    assert_selector("body")
  end

  def test_login_and_logout
    login!(rolf)

    visit("/info/how_to_help")
    assert_selector("body.info__how_to_help")
    assert_no_link(href: "/account/login/new")
    assert_button(:app_logout.l)
    assert_no_link(:app_logout.l)
    assert_link(href: "/users/#{rolf.id}")

    first(:button, text: :app_logout.l).click
    assert_selector("body.login__logout")
    assert_link(href: "/account/login/new")
    assert_no_button(:app_logout.l)
    assert_no_link(:app_logout.l)
    assert_no_link(href: "/users/#{rolf.id}")

    click_link(text: "Introduction")
    assert_selector("body.info__intro")
    assert_link(href: "/account/login/new")
    assert_no_button(:app_logout.l)
    assert_no_link(:app_logout.l)
    assert_no_link(href: "/users/#{rolf.id}")
  end

  def test_sessions
    rolf_session = open_session
    login(rolf, session: rolf_session)
    mary_session = open_session
    login(mary, session: mary_session)
    katrina_session = open_session
    login(katrina, session: katrina_session)
    assert_equal(true, true) # Rails complains this test has no assertions

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

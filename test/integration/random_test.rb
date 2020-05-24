require "test_helper"

class RandomTest < IntegrationTestCase
  test "pivotal tracker" do
    get("/")
    click(label: "Feature Tracker")
    assert_template("pivotal/index")
  end

  # Test "/controller/action/type/id" route used by AJAX controller.
  test "ajax router" do
    get("/ajax/auto_complete/name/Agaricus")
    assert_response(:success)
    lines = response.body.split("\n")
    assert_equal("A", lines.first)
    assert(lines.include?("Agaricus"))
    assert(lines.include?("Agaricus campestris"))
  end

  test "the homepage" do
    get("/")
    assert_template("observer/list_rss_logs")
    assert(/account/i, response.body)
  end

  test "login and logout" do
    login!(rolf)

    get("/observer/how_to_help")
    assert_template("observer/how_to_help")
    assert_no_link_exists("/account/login")
    assert_link_exists("/account/logout_user")
    assert_link_exists("/observer/show_user/#{rolf.id}")

    click(label: "Logout")
    assert_template("account/logout_user")
    assert_link_exists("/account/login")
    assert_no_link_exists("/account/logout_user")
    assert_no_link_exists("/observer/show_user/#{rolf.id}")

    click(label: "How To Help")
    assert_template("observer/how_to_help")
    assert_link_exists("/account/login")
    assert_no_link_exists("/account/logout_user")
    assert_no_link_exists("/observer/show_user/#{rolf.id}")
  end

  test "sessions" do
    rolf_session = open_session
    app = rolf_session.app
    rolf_session.login(rolf)
    mary_session = open_session
    mary_session.login(mary)
    katrina_session = open_session
    katrina_session.login(katrina)

    rolf_session.get("/")
    assert(/rolf/i, rolf_session.response.body)
    assert_not_equal(rolf_session.session[:session_id],
                     mary_session.session[:session_id])
    assert_not_equal(katrina_session.session[:session_id],
                     mary_session.session[:session_id])
  end
end

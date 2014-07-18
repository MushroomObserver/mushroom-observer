# encoding: utf-8

require 'test_helper'

class RandomTest < IntegrationTestCase
  include SessionExtensions
  fixtures :names
  
  test "pivotal tracker" do
    get('/')
    click(:label => 'Feature Tracker')
    assert_template('pivotal/index')
  end

  # Test "/controller/action/type/id" route used by AJAX controller.
  test "ajax router" do
    get('/ajax/auto_complete/name/Agaricus')
    assert_response(:success)
    lines = response.body.split("\n")
    assert_equal('A', lines.first)
    assert(lines.include?('Agaricus'))
    assert(lines.include?('Agaricus campestris'))
  end

  test "the homepage" do
    get('/')
    assert_template('observer/list_rss_logs')
    assert(/account/i, response.body)
  end

  test "login" do
    rolf_session = new_user_session(rolf)
    rolf_session.get('/')
    assert(/current user/i, rolf_session.response.body)
  end
  
  test "sessions" do
    rolf_session = login(rolf)
    mary_session = login(mary)
    katrina_session = login(katrina)
    
    rolf_session.get('/')
    assert(/rolf/i, rolf_session.response.body)

    assert_not_equal(rolf_session.session[:session_id], mary_session.session[:session_id])
    assert_not_equal(katrina_session.session[:session_id], mary_session.session[:session_id])
  end
end

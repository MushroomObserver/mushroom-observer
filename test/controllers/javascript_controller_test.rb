# frozen_string_literal: true

require("test_helper")

# Controller tests for javascript utilities
class JavascriptControllerTest < FunctionalTestCase
  def test_javascript_override
    get(:turn_javascript_on)
    assert_response(:redirect)
    assert_equal(:on, session[:js_override])

    get(:turn_javascript_off)
    assert_response(:redirect)
    assert_equal(:off, session[:js_override])

    get(:turn_javascript_nil)
    assert_response(:redirect)
    assert_nil(session[:js_override])
  end
end
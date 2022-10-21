# frozen_string_literal: true

require("test_helper")

# Controller tests for info pages
class AdminControllerTest < FunctionalTestCase
  def test_basic_access
    login
    assert_false(session[:admin])
    rolf.admin = true
    rolf.save!

    get(:show)
    assert_redirected_to(new_account_login_path)

    session[:admin] = true
    get(:show)
    assert_template("admin/show")
  end
end

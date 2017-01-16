require "test_helper"

# Tests which supplement controller/observer_controller_test.rb
class ObserverControllerSupplementalTest < IntegrationTestCase
  # ----------------------------
  #  BackwardsCompatibility
  # ----------------------------
  def test_backward_compatibility
    obj = "name"
    old_method = "bogus_name_method"
    new_method = "show_name"
    id = names(:coprinus_comatus).id

    # Prove that action_has_moved creates method named old_method
    ObserverController::action_has_moved(obj, old_method, new_method)
    assert(ObserverController.method_defined?(old_method))

    # Log in to avoid issues with before_action :login_required.
    # (This should go away if BackwardCompatibility gets changed
    # to not require login for every old method.)
    user = users(:rolf)
    visit("/account/login")
    fill_in("User name or Email address:", with: user.login)
    fill_in("Password:", with: "testpassword")
    click_button("Login")

    # Prove that request to observer/old_method?id=x
    # redirects to obj/new_method?id=x
    visit("/observer/#{old_method}?id=#{id}")
    assert_equal("http://www.example.com/#{obj}/#{new_method}?id=#{id}",
                 page.current_url)

    # Prove that request to observer/old_method/nnn
    # redirects to obj/new_method/nnn
    visit("/observer/#{old_method}/#{id.to_s}")
    assert_equal("http://www.example.com/#{obj}/#{new_method}/#{id}",
                 page.current_url)

    # Clean up the bogus method.
    ObserverController.send(:remove_method, old_method)
    refute(ObserverController.method_defined?(old_method))
  end
end

# frozen_string_literal: true

require("test_helper")

class Admin::BannersControllerTest < FunctionalTestCase
  setup do
    make_admin("admin")
  end

  test "should get index" do
    get(:index)
    assert_response :success
    assert_select "textarea", banners(:one).message
  end

  test "should create banner" do
    assert_difference("Banner.count", 1) do
      post(:create, params: { banner: { message: "New Banner" } })
    end

    assert_redirected_to admin_banners_path
  end

  test "should not create banner with empty message" do
    assert_no_difference("Banner.count") do
      post(:create, params: { banner: { message: "" } })
    end

    assert_response :success
    assert_select "div", "Failed to update banner."
  end
end

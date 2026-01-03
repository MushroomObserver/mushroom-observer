# frozen_string_literal: true

require("test_helper")

class Admin::BannersControllerTest < FunctionalTestCase
  setup do
    make_admin("admin")
  end

  def test_should_get_index
    get(:index)
    assert_response(:success)
    assert_select("textarea", banners(:one).message)
  end

  def test_should_create_banner
    assert_difference("Banner.count", 1) do
      post(:create, params: { banner: { message: "New Banner" } })
    end

    assert_redirected_to(admin_banners_path)
  end

  def test_should_not_create_banner_with_empty_message
    assert_no_difference("Banner.count") do
      post(:create, params: { banner: { message: "" } })
    end

    assert_response(:success)
    assert_select("div", "Failed to update banner.")
  end
end

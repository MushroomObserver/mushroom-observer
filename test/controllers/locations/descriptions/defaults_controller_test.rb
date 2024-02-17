# frozen_string_literal: true

require("test_helper")

module Locations::Descriptions
  class DefaultsControllerTest < FunctionalTestCase
    def make_description_default_helper(desc)
      user = desc.user
      params = {
        id: desc.id
      }
      put_requires_login(:update, params, user.login)
    end

    def test_make_description_default
      desc = location_descriptions(:user_public_location_desc)
      assert_not_equal(desc, desc.parent.description)
      make_description_default_helper(desc)
      desc.parent.reload
      assert_equal(desc, desc.parent.description)
    end

    def test_non_public_description_cannot_be_default
      desc = location_descriptions(:user_private_location_desc)
      assert_nil(desc.parent.description)
      make_description_default_helper(desc)
      desc.parent.reload
      assert_not_equal(desc, desc.parent.description)
      assert_nil(desc.parent.description)
    end
  end
end

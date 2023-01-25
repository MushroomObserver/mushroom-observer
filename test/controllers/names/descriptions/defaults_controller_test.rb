# frozen_string_literal: true

require("test_helper")
require("set")

module Names::Descriptions
  class DefaultsControllerTest < FunctionalTestCase
    def make_description_default_helper(desc)
      user = desc.user
      params = {
        id: desc.id
      }
      put_requires_login(:update, params, user.login)
    end

    def test_make_description_default
      desc = name_descriptions(:peltigera_alt_desc)
      assert_not_equal(desc, desc.parent.description)
      make_description_default_helper(desc)
      desc.parent.reload
      assert_equal(desc, desc.parent.description)
    end

    def test_non_public_description_cannot_be_default
      desc = name_descriptions(:peltigera_user_desc)
      current_default = desc.parent.description
      make_description_default_helper(desc)
      desc.parent.reload
      assert_not_equal(desc, desc.parent.description)
      assert_equal(current_default, desc.parent.description)
    end
  end
end

# frozen_string_literal: true

require("test_helper")
require("set")

module Names::Descriptions
  class PermissionsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_group_name_of_one_user_group
      assert_equal(:adjust_permissions_all_users.t,
                   @controller.group_name(user_groups(:all_users)))
      assert_equal(:REVIEWERS.t,
                   @controller.group_name(user_groups(:reviewers)))
      assert_equal(rolf.legal_name,
                   @controller.group_name(user_groups(:rolf_only)))
      assert_equal("article writers",
                   @controller.group_name(user_groups(:article_writers)))
    end
  end
end

# frozen_string_literal: true

require("test_helper")
require("set")

module Names::Descriptions
  class PermissionsControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def peltigera_desc
      name_descriptions(:peltigera_desc)
    end

    def draft_cc_desc
      name_descriptions(:draft_coprinus_comatus)
    end

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

    def test_form_access
      get(:edit, params: { id: draft_cc_desc.id })
      assert_redirected_to(new_account_login_path)

      # dick is not permitted
      login("dick")
      get(:edit, params: { id: draft_cc_desc.id })
      assert_redirected_to(name_description_path(draft_cc_desc.id))

      # rolf is in eol_admins. and he should be an admin of this desc.
      login("rolf")
      get(:edit, params: { id: draft_cc_desc.id })
      assert_response(:success)

      # rolf is also in reviewers. and they are admins of this desc.
      # but access denied, because this description is public!
      get(:edit, params: { id: peltigera_desc.id })
      assert_redirected_to(name_description_path(peltigera_desc.id))
    end
  end
end

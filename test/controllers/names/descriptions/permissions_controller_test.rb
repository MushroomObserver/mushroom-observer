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

    # draft_cc_desc has
    # reader_groups: eol_users plus katrina_only
    # writer_groups: eol_admins plus katrina_only,
    # admin_groups: eol_admins plus katrina_only,
    def test_change_permissions
      assert_equal(draft_cc_desc.reader_group_ids,
                   [user_groups(:eol_users).id, user_groups(:katrina_only).id])
      assert_equal(draft_cc_desc.writer_group_ids,
                   [user_groups(:eol_admins).id, user_groups(:katrina_only).id])
      assert_equal(draft_cc_desc.admin_group_ids,
                   [user_groups(:eol_admins).id, user_groups(:katrina_only).id])
      params = {
        id: draft_cc_desc.id,
        group_reader: { user_groups(:eol_admins).id => 1 },
        group_writer: { user_groups(:eol_admins).id => 0 },
        group_admin: { user_groups(:eol_admins).id => 1 },
        writein_name: { 1 => "dick", 2 => "", 3 => "",
                        4 => "", 5 => "", 6 => "" },
        writein_reader: { 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0 },
        writein_writer: { 1 => 1, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0 },
        writein_admin: { 1 => 1, 2 => 0, 3 => 0, 4 => 0, 5 => 0, 6 => 0 }
      }

      # Dick is not permitted to edit.
      login("dick")
      put(:update, params: params)
      assert_flash_text(/You must be an admin for a description/)

      # Rolf is permitted to edit.
      login("rolf")
      # Try to edit a different, public description: no dice
      put(:update, params: params.merge(id: peltigera_desc.id))
      assert_flash_text(/This type of description has fixed permissions/)

      # Edit this description's permissions.
      put(:update, params: params)
      assert_redirected_to(name_description_path(draft_cc_desc.id))
      fx = get_last_flash
      assert_includes(fx, "Gave view permission to EOL Project.admin")
      assert_includes(fx, "Gave edit permission to Tricky Dick")
      assert_includes(fx, "Revoked edit permission for EOL Project.admin")
      assert_includes(fx, "Gave admin permission to Tricky Dick")
    end
  end
end

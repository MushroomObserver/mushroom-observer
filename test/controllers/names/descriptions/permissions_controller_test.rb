# frozen_string_literal: true

require("test_helper")

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
        description_permissions: writein_params(
          name_1: "dick", writer_1: "1", admin_1: "1"
        ).merge(
          group_reader: [user_groups(:eol_admins).id],
          group_writer: [],
          group_admin: [user_groups(:eol_admins).id]
        )
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

    # Cover writein with email format "Name <email>"
    def test_change_permissions_writein_email_format
      desc = draft_cc_desc
      login("rolf")
      params = {
        id: desc.id,
        description_permissions: writein_params(
          name_1: "dick <dick@email.com>", reader_1: "1"
        ).merge(
          group_reader: desc.reader_group_ids,
          group_writer: desc.writer_group_ids,
          group_admin: desc.admin_group_ids
        )
      }
      put(:update, params: params)
      assert_redirected_to(name_description_path(desc.id))
      assert_flash(/Gave view permission to Tricky Dick/)
    end

    # Cover writein with invalid user - should flash error and re-render form
    def test_change_permissions_writein_invalid_user
      desc = draft_cc_desc
      login("rolf")
      params = {
        id: desc.id,
        description_permissions: writein_params(
          name_1: "nonexistent_user_xyz", reader_1: "1"
        ).merge(
          group_reader: desc.reader_group_ids,
          group_writer: desc.writer_group_ids,
          group_admin: desc.admin_group_ids
        )
      }
      put(:update, params: params)
      assert_flash(/not found/)
      assert_template("edit")
    end

    # Cover no changes made
    def test_change_permissions_no_changes
      desc = draft_cc_desc
      login("rolf")
      params = {
        id: desc.id,
        description_permissions: writein_params.merge(
          group_reader: desc.reader_group_ids,
          group_writer: desc.writer_group_ids,
          group_admin: desc.admin_group_ids
        )
      }
      put(:update, params: params)
      assert_redirected_to(name_description_path(desc.id))
      assert_flash(/No changes/)
    end

    # With array format, invalid group IDs are simply ignored (not in @groups)
    def test_change_permissions_invalid_group_id_ignored
      desc = draft_cc_desc
      login("rolf")
      params = {
        id: desc.id,
        description_permissions: writein_params.merge(
          group_reader: [999999],
          group_writer: [],
          group_admin: []
        )
      }
      put(:update, params: params)
      # Invalid IDs are ignored since they're not in @groups
      assert_redirected_to(name_description_path(desc.id))
    end

    # Cover changing public flag via reader_groups
    def test_change_permissions_updates_public_flag
      desc = draft_cc_desc
      assert_false(desc.public)

      login("rolf")
      params = {
        id: desc.id,
        description_permissions: writein_params.merge(
          group_reader: [user_groups(:all_users).id],
          group_writer: [],
          group_admin: []
        )
      }
      put(:update, params: params)
      assert_redirected_to(name_description_path(desc.id))
      desc.reload
      assert_true(desc.public)
    end

    private

    # Generate writein params with defaults, allowing overrides
    def writein_params(**overrides)
      result = {}
      (1..6).each do |i|
        result[:"writein_name_#{i}"] = overrides[:"name_#{i}"] || ""
        result[:"writein_reader_#{i}"] = overrides[:"reader_#{i}"] || "0"
        result[:"writein_writer_#{i}"] = overrides[:"writer_#{i}"] || "0"
        result[:"writein_admin_#{i}"] = overrides[:"admin_#{i}"] || "0"
      end
      result
    end
  end
end

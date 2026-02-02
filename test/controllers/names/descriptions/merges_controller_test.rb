# frozen_string_literal: true

require("test_helper")

module Names::Descriptions
  class MergesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    # Rolf is the author of an alternative desc.
    # It's not restricted.
    def rolf_desc
      name_descriptions(:peltigera_alt_desc)
    end

    # Mary wrote this one.
    # The writer and reader groups are mary_only and dick_only
    # Rolf shouldn't be able to merge with it.
    def mary_desc
      name_descriptions(:peltigera_user_desc)
    end

    def test_form_permissions
      # login rolf, and try to access.
      login("rolf")
      # get(:new, params: { id: "bogus" }) # Will not work, must be integer
      # assert_redirected_to(name_descriptions_index_path)

      get(:new, params: { id: rolf_desc.id })
      assert_response(:success)

      # Now try to access from mary's. Should get bounced, redirected to name
      get(:new, params: { id: mary_desc.id })
      assert_redirected_to(name_path(mary_desc.parent_id))

      # Now switch to dick.
      login("dick")
      # Mary's desc is restricted. But dick should be able to edit
      get(:new, params: { id: mary_desc.id })
      assert_response(:success)

      # Rolf's is public, dick should be able to access also
      get(:new, params: { id: rolf_desc.id })
      assert_response(:success)
    end

    def test_merge_descriptions_no_permission
      login("rolf")
      params = {
        id: rolf_desc.id,
        target: mary_desc.id,
        delete: 0
      }
      post(:create, params: params)
      assert_flash_text(/You have not been given permission/)
    end

    def test_merge_descriptions_notes_conflict
      login("dick")
      params = {
        id: rolf_desc.id,
        target: mary_desc.id,
        delete: 0
      }
      post(:create, params: params)
      # shouldn't work, there is a conflict. requires manual resolution
      assert_flash_text(/Please merge the two descriptions/)
      # dick didn't delete, so the original desc should still be there.
      assert(rolf_desc.reload)

      # now try with delete. Also shouldn't work, there is a conflict
      params = {
        id: rolf_desc.id,
        target: mary_desc.id,
        delete: 1
      }
      post(:create, params: params)
      assert_flash_text(/Please merge the two descriptions/)
      assert(rolf_desc.reload)

      # Blank the first gen_desc to avoid conflict.
      rolf_desc.update(gen_desc: nil)
      rolf_desc.reload
      assert_nil(rolf_desc.gen_desc)
      rd_id = rolf_desc.id

      # Merge should work, no delete.
      params = {
        id: rolf_desc.id,
        target: mary_desc.id,
        delete: 0
      }
      post(:create, params: params)
      assert_flash_text(/Successfully merged the descriptions/)
      assert_equal(rolf_desc.reload, NameDescription.find(rd_id))

      # Delete after merge will not work even if specified. dick is not an admin
      params = {
        id: rolf_desc.id,
        target: mary_desc.id,
        delete: 1
      }
      post(:create, params: params)
      assert_flash_text(/Successfully merged the descriptions/)
      assert_equal(rolf_desc.reload, NameDescription.find(rd_id))

      # To merge with delete, make dick an admin in_admin_mode
      make_admin("dick")
      post(:create, params: params)
      assert_flash_text(/Successfully merged the descriptions/)
      assert_raises(ActiveRecord::RecordNotFound) do
        NameDescription.find(rd_id)
      end
    end

    def test_merge_with_nonexistant_description
      login("rolf")
      params = {
        id: rolf_desc.id,
        target: "bogus",
        delete: 0
      }
      post(:create, params: params)
      assert_flash_text(/Sorry, the name description you tried to display/)
    end

    # Cover delete_src_description_and_update_parent when src was default
    def test_merge_and_delete_default_description
      name = names(:conocybe_filaris)
      # Create two descriptions - src with no notes (mergeable),
      # dest fully public
      src_desc = NameDescription.create!(
        name: name, user: rolf, source_type: "user", gen_desc: nil, public: true
      )
      src_desc.admin_groups << UserGroup.one_user(rolf)
      src_desc.writer_groups << UserGroup.all_users
      src_desc.reader_groups << UserGroup.all_users

      # Dest must be fully_public: public=true and writer_groups == [all_users]
      dest_desc = NameDescription.create!(
        name: name, user: rolf, source_type: "user",
        gen_desc: "Destination notes", public: true
      )
      dest_desc.admin_groups << UserGroup.one_user(rolf)
      # Only all_users in writer_groups makes public_write_was return true
      dest_desc.writer_groups.clear
      dest_desc.writer_groups << UserGroup.all_users
      dest_desc.reader_groups << UserGroup.all_users

      # Make src the default
      name.description = src_desc
      name.save!

      login("rolf")
      params = {
        id: src_desc.id,
        target: dest_desc.id,
        delete: "1"
      }
      post(:create, params: params)

      assert_flash(/Successfully merged/)
      # Source should be deleted
      assert_nil(NameDescription.safe_find(src_desc.id))
      # Destination should be the new default
      name.reload
      assert_equal(dest_desc.id, name.description_id)
    end

    # Cover check_src_permission! method (lines 50-52) - POST create on private
    def test_merge_private_description_no_read_permission
      # Rolf tries to merge mary's private description via POST create
      # mary_desc reader_groups are mary_only and dick_only,
      # so rolf can't read it
      login("rolf")
      params = {
        id: mary_desc.id,
        target: rolf_desc.id,
        delete: 0
      }
      post(:create, params: params)
      assert_flash_error(:runtime_description_private.t)
      assert_redirected_to(name_path(mary_desc.parent_id))
    end

    # Cover check_src_exists! returning false (line 44)
    def test_merge_nonexistent_source_description
      login("rolf")
      params = {
        id: 999_999,
        target: rolf_desc.id,
        delete: 0
      }
      post(:create, params: params)
      assert_flash_error
      assert_redirected_to(name_descriptions_index_path)
    end
  end
end

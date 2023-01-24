# frozen_string_literal: true

require("test_helper")
require("set")

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
      get(:new, params: { id: "bogus" })
      assert_redirected_to(name_descriptions_path)

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
  end
end

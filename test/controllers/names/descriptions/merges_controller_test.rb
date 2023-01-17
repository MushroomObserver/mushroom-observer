# frozen_string_literal: true

require("test_helper")
require("set")

module Names::Descriptions
  class MergesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_try_merge_descriptions_no_permission
      # Rolf is the author of an alternative desc.
      # It's not restricted.
      rolf_desc = name_descriptions(:peltigera_alt_desc)
      # Mary wrote this one.
      # The writer and reader groups are mary_only and dick_only
      # Rolf shouldn't be able to merge with it.
      mary_desc = name_descriptions(:peltigera_user_desc)
      # First test if dick can access the merge form
      login("dick")
      get(:new, params: { id: rolf_desc.id })
      assert_response(:success)

      login("rolf")
      get(:new, params: { id: rolf_desc.id })
      assert_response(:success)
      params = {
        id: rolf_desc.id,
        target: mary_desc.id,
        delete: 0
      }
      post(:create, params: params)
      assert_flash_error(:runtime_edit_description_denied.t)

      # Now try the other way around. Should get redirected to name
      get(:new, params: { id: mary_desc.id })
      assert_redirected_to(name_path(mary_desc.parent_id))
    end

    def test_merge_descriptions; end

    def test_merge_descriptions_notes_conflict; end

    def test_merge_incompatible_descriptions; end
  end
end

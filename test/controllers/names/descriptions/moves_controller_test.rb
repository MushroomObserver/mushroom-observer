# frozen_string_literal: true

require("test_helper")

module Names::Descriptions
  class MovesControllerTest < FunctionalTestCase
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

    # The full "official" desc
    def peltigera_desc
      name_descriptions(:peltigera_desc)
    end

    def peltigera_name
      names(:peltigera)
    end

    def coprinus_name
      names(:coprinus)
    end

    # A name with no desc
    def stereum_name
      names(:stereum)
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

    def test_move_descriptions_permissions
      login("rolf")
      assert_equal(rolf_desc.parent_id, peltigera_name.id)

      params = {
        id: rolf_desc.id,
        description_move_or_merge: { target: coprinus_name.id, delete: 0 }
      }
      post(:create, params: params)
      assert_flash_success

      assert_equal(mary_desc.parent_id, peltigera_name.id)

      params = {
        id: mary_desc.id,
        description_move_or_merge: { target: coprinus_name.id, delete: 0 }
      }
      post(:create, params: params)
      assert_flash_error

      login("mary")
      post(:create, params: params)
      assert_flash_success
      # It should get cloned. Reload the descriptions, not the name
      new_desc = coprinus_name.descriptions.reload.last
      assert_equal(NameDescription.last.id, new_desc.id)

      # Try with delete
      params = {
        id: mary_desc.id,
        description_move_or_merge: { target: coprinus_name.id, delete: 1 }
      }
      post(:create, params: params)
      assert_flash_success
    end

    def test_move_description_clashing_classifications
      login("dick")
      params = {
        id: peltigera_desc.id,
        description_move_or_merge: { target: names(:basidiomycota).id,
                                     delete: 0 }
      }
      post(:create, params: params)
      assert_flash_text(/The classification has incorrect syntax/)

      # Now try compatible classification
      params = {
        id: peltigera_desc.id,
        description_move_or_merge: { target: coprinus_name.id, delete: 0 }
      }
      post(:create, params: params)
      assert_flash_success
      assert_redirected_to(name_description_path(NameDescription.last.id))
    end

    def test_move_description_to_nonexistant_name
      login("dick")
      params = {
        id: peltigera_desc.id,
        description_move_or_merge: { target: "bogus", delete: 0 }
      }
      post(:create, params: params)
      assert_flash_text(/Sorry, the name you tried to display/)
    end

    # if @delete_after & src_was_default
    def test_move_description_replacing_default
      login("dick")
      params = {
        id: peltigera_desc.id,
        description_move_or_merge: { target: stereum_name.id, delete: 1 }
      }

      post(:create, params: params)
      assert_flash_success
      assert_redirected_to(name_description_path(peltigera_desc.id))
      assert_equal(stereum_name.reload.description_id, peltigera_desc.id)
    end

    # Cover check_src_permission! method - POST create on private desc
    def test_move_private_description_no_read_permission
      # Rolf tries to move mary's private description via POST create
      login("rolf")
      params = {
        id: mary_desc.id,
        description_move_or_merge: { target: coprinus_name.id, delete: 0 }
      }
      post(:create, params: params)
      assert_flash_error(:runtime_description_private.t)
      assert_redirected_to(name_path(mary_desc.parent_id))
    end

    # Cover check_src_exists! returning false (line 43)
    def test_move_nonexistent_source_description
      login("rolf")
      params = {
        id: 999_999,
        description_move_or_merge: { target: coprinus_name.id, delete: 0 }
      }
      post(:create, params: params)
      assert_flash_error
      assert_redirected_to(name_descriptions_index_path)
    end

    # Cover flash_object_errors when cloned description fails validation
    # (line 148)
    def test_move_description_clone_fails_validation
      login("rolf")
      params = {
        id: rolf_desc.id,
        description_move_or_merge: { target: coprinus_name.id, delete: 0 }
      }

      # Create a mock description that fails save
      desc = NameDescription.new(name: names(:coprinus), user: rolf)
      desc.errors.add(:base, "Test validation error")

      desc.stub(:save, false) do
        NameDescription.stub(:new, desc) do
          post(:create, params: params)
        end
      end

      assert_flash_error
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module Locations::Descriptions
  class MergesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    # Dick's public desc for gualala. Readable/writable by all.
    def public_desc
      location_descriptions(:user_public_location_desc)
    end

    # Dick's private desc for gualala. Only dick can read/write.
    def private_desc
      location_descriptions(:bolete_project_private_location_desc)
    end

    # Another of dick's private descs for gualala.
    def other_private_desc
      location_descriptions(:user_private_location_desc)
    end

    def test_form_permissions
      # Dick can access his public desc
      login("dick")
      get(:new, params: { id: public_desc.id })
      assert_response(:success)

      # Dick can access his private desc
      get(:new, params: { id: private_desc.id })
      assert_response(:success)

      # Rolf cannot access dick's private desc
      login("rolf")
      get(:new, params: { id: private_desc.id })
      assert_redirected_to(location_path(private_desc.parent_id))
    end

    def test_merge_descriptions_no_permission
      # Rolf can read the public desc but can't write to private desc
      login("rolf")
      params = {
        id: public_desc.id,
        description_move_or_merge: { target: private_desc.id, delete: 0 }
      }
      post(:create, params: params)
      assert_flash_text(/You have not been given permission/)
    end

    def test_merge_descriptions_notes_conflict
      login("dick")
      # Both descs have notes → conflict
      params = {
        id: public_desc.id,
        description_move_or_merge: {
          target: other_private_desc.id, delete: 0
        }
      }
      post(:create, params: params)
      assert_flash_text(/Please merge the two descriptions/)

      # Clear notes on source to remove conflict
      public_desc.update(notes: nil)
      post(:create, params: params)
      assert_flash_text(/Successfully merged the descriptions/)
    end

    def test_merge_with_nonexistant_description
      login("dick")
      params = {
        id: public_desc.id,
        description_move_or_merge: { target: "bogus", delete: 0 }
      }
      post(:create, params: params)
      assert_flash_text(
        /Sorry, the location description you tried to display/
      )
    end

    # Cover check_src_permission! method - POST create on private desc
    def test_merge_private_description_no_read_permission
      login("rolf")
      params = {
        id: private_desc.id,
        description_move_or_merge: { target: public_desc.id, delete: 0 }
      }
      post(:create, params: params)
      assert_flash_error(:runtime_description_private.t)
      assert_redirected_to(location_path(private_desc.parent_id))
    end

    # Cover check_src_exists! returning false
    def test_merge_nonexistent_source_description
      login("rolf")
      params = {
        id: 999_999,
        description_move_or_merge: { target: public_desc.id, delete: 0 }
      }
      post(:create, params: params)
      assert_flash_error
      assert_redirected_to(location_descriptions_index_path)
    end

    # Cover delete_src_description_and_update_parent when src was default
    def test_merge_and_delete_default_description
      location = locations(:gualala)
      # Create two descriptions: src with no notes (mergeable),
      # dest fully public
      src_desc = LocationDescription.create!(
        location: location, user: rolf, source_type: "user",
        notes: nil, public: true
      )
      src_desc.admin_groups << UserGroup.one_user(rolf)
      src_desc.writer_groups << UserGroup.all_users
      src_desc.reader_groups << UserGroup.all_users

      dest_desc = LocationDescription.create!(
        location: location, user: rolf, source_type: "user",
        notes: "Destination notes", public: true
      )
      dest_desc.admin_groups << UserGroup.one_user(rolf)
      dest_desc.writer_groups.clear
      dest_desc.writer_groups << UserGroup.all_users
      dest_desc.reader_groups << UserGroup.all_users

      # Make src the default
      location.description = src_desc
      location.save!

      login("rolf")
      params = {
        id: src_desc.id,
        description_move_or_merge: { target: dest_desc.id, delete: "1" }
      }
      post(:create, params: params)

      assert_flash(/Successfully merged/)
      # Source should be deleted
      assert_nil(LocationDescription.safe_find(src_desc.id))
      # Destination should be the new default
      location.reload
      assert_equal(dest_desc.id, location.description_id)
    end
  end
end

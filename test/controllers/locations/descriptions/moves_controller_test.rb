# frozen_string_literal: true

require("test_helper")

module Locations::Descriptions
  class MovesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    # Dick's public desc for gualala. Readable/writable by all.
    def public_desc
      location_descriptions(:user_public_location_desc)
    end

    # Dick's private desc for gualala. Only dick can read/write.
    def private_desc
      location_descriptions(:bolete_project_private_location_desc)
    end

    def gualala_location
      locations(:gualala)
    end

    def burbank_location
      locations(:burbank)
    end

    # A location with no descriptions
    def albion_location
      locations(:albion)
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

    def test_move_descriptions_permissions
      login("dick")
      assert_equal(public_desc.parent_id, gualala_location.id)

      # Dick can move his public desc (clone, no delete)
      params = {
        id: public_desc.id,
        description_move_or_merge: {
          target: burbank_location.id, delete: 0
        }
      }
      post(:create, params: params)
      assert_flash_success
    end

    def test_move_description_to_nonexistant_location
      login("dick")
      params = {
        id: public_desc.id,
        description_move_or_merge: { target: "bogus", delete: 0 }
      }
      post(:create, params: params)
      assert_flash_text(/Sorry, the location you tried to display/)
    end

    def test_move_description_replacing_default
      login("dick")
      # burbank has no descriptions, no default
      params = {
        id: public_desc.id,
        description_move_or_merge: {
          target: burbank_location.id, delete: 1
        }
      }

      # public_desc is the default for gualala
      assert_equal(gualala_location.description_id, public_desc.id)

      post(:create, params: params)
      assert_flash_success
      assert_redirected_to(
        location_description_path(public_desc.id)
      )
      # After move, it should be the default for burbank
      # (since it was default for gualala and dest had no default)
      assert_equal(burbank_location.reload.description_id,
                   public_desc.id)
    end

    # Cover check_src_permission! method - POST create on private desc
    def test_move_private_description_no_read_permission
      login("rolf")
      params = {
        id: private_desc.id,
        description_move_or_merge: {
          target: burbank_location.id, delete: 0
        }
      }
      post(:create, params: params)
      assert_flash_error(:runtime_description_private.t)
      assert_redirected_to(location_path(private_desc.parent_id))
    end

    # Cover flash_object_errors when cloned description fails validation
    def test_move_description_clone_fails_validation
      login("dick")
      params = {
        id: public_desc.id,
        description_move_or_merge: {
          target: burbank_location.id, delete: 0
        }
      }

      desc = LocationDescription.new(
        location: burbank_location, user: dick
      )
      desc.errors.add(:base, "Test validation error")

      desc.stub(:save, false) do
        LocationDescription.stub(:new, desc) do
          post(:create, params: params)
        end
      end

      assert_flash_error
    end

    # Cover check_src_exists! returning false
    def test_move_nonexistent_source_description
      login("rolf")
      params = {
        id: 999_999,
        description_move_or_merge: {
          target: burbank_location.id, delete: 0
        }
      }
      post(:create, params: params)
      assert_flash_error
      assert_redirected_to(location_descriptions_index_path)
    end
  end
end

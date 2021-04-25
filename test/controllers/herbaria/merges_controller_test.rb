# frozen_string_literal: true

require("test_helper")

module Herbaria
  # tests of action to merge two herbaria
  class MergesControllerTest < FunctionalTestCase
    # ---------- Helpers ----------

    def field_museum
      herbaria(:field_museum)
    end

    def fundis
      herbaria(:fundis_herbarium)
    end

    def nybg
      herbaria(:nybg_herbarium)
    end

    def herbarium_params
      {
        name: "",
        personal: "",
        code: "",
        place_name: "",
        email: "",
        mailing_address: "",
        description: ""
      }.freeze
    end

    # ---------- Actions to Display data (index, show, etc.) -------------------

    # ---------- Actions to Display forms -- (new, edit, etc.) -----------------

    # ---------- Actions to Modify data: (create, update, destroy, etc.) -------

    def test_merge
      # Rule is non-admins can only merge herbaria in which they own all records
      # into their own personal herbarium. Nothing else. Mary owns all the
      # records at fundis, randomly enough, so if we create a personal
      # herbarium for her, she should be able to merge fundis into it.
      assert_true(fundis.owns_all_records?(mary))
      src = fundis
      dest = mary.create_personal_herbarium
      # dest_old_name = dest.name
      login("mary")

      assert_no_changes(
        "dest.name", "Destination Herbarium should retain its name"
      ) do
        post(:create, params: { src: src.id, dest: dest.id })
      end
      assert_flash_success
      assert_redirected_to(herbaria_path(id: dest.id))
      assert_equal(
        dest.personal_user_id, mary.id,
        "Destination Herbarium should remain Mary's personal Herbarium"
      )
    end

    def test_merge_admin
      make_admin("mary")
      post(:create, params: { src: nybg.id, dest: field_museum.id })
      assert_flash_success
      assert_redirected_to(herbaria_path(id: field_museum))
    end

    def test_merge_no_login
      marys = mary.create_personal_herbarium
      post(:create, params: { src: fundis.id, dest: marys.id })
      assert_redirected_to(account_login_path)
    end

    def test_merge_by_record_nonowner
      marys = mary.create_personal_herbarium
      login("rolf")
      post(:create, params: { src: fundis.id, dest: marys.id })

      assert_redirected_to(
        observer_email_merge_request_path(
          type: :Herbarium, old_id: fundis.id, new_id: marys.id
        )
      )
    end

    def test_merge_no_params
      login("mary")
      post(:create)
      assert_flash_error
    end

    def test_merge_personal_herbarium_into_itself
      marys = mary.create_personal_herbarium
      login("mary")
      post(:create, params: { src: marys.id, dest: marys.id })
      assert_no_flash
    end

    def test_merge_non_existent_merge_source
      login("mary")
      post(:create, params: { src: 666 })
      assert_flash_error
    end

    def test_merge_non_existent_merge_target
      login("mary")
      post(:create, params: { src: fundis.id, dest: 666 })
      assert_flash_error
    end

    def test_merge_identical_non_personal_herbaria
      login("mary")
      post(:create, params: { src: nybg.id, dest: nybg.id })

      assert_redirected_to(
        observer_email_merge_request_path(
          type: :Herbarium, old_id: nybg.id, new_id: nybg.id
        )
      )
    end

    def test_merge_valid_source_into_non_personal_target
      login("mary")
      post(:create, params: { src: fundis.id, dest: nybg.id })
      assert_redirected_to(
        observer_email_merge_request_path(
          type: :Herbarium, old_id: fundis.id, new_id: nybg.id
        )
      )
    end
  end
end

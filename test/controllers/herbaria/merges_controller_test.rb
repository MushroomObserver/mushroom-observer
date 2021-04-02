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
      marys = mary.create_personal_herbarium
      login("mary")
      post(:create, params: { this: fundis.id, that: marys.id })

      assert_flash_success
      # fundis ends up being the destination because it is older.
      assert_redirected_to(herbaria_path(id: fundis))
    end

    def test_merge_admin
      make_admin("mary")
      post(:create, params: { this: nybg.id, that: field_museum.id })
      assert_flash_success
      # nybg survives because it is older.
      assert_redirected_to(herbaria_path(id: nybg))
    end

    def test_merge_no_login
      marys = mary.create_personal_herbarium
      post(:create, params: { this: fundis.id, that: marys.id })
      assert_redirected_to(account_login_path)
    end

    def test_merge_by_record_nonowner
      marys = mary.create_personal_herbarium
      login("rolf")
      post(:create, params: { this: fundis.id, that: marys.id })

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
      post(:create, params: { this: marys.id, that: marys.id })
      assert_no_flash
    end

    def test_merge_non_existent_merge_source
      login("mary")
      post(:create, params: { this: 666 })
      assert_flash_error
    end

    def test_merge_non_existent_merge_target
      login("mary")
      post(:create, params: { this: fundis.id, that: 666 })
      assert_flash_error
    end

    def test_merge_identical_non_personal_herbaria
      login("mary")
      post(:create, params: { this: nybg.id, that: nybg.id })

      assert_redirected_to(
        observer_email_merge_request_path(
          type: :Herbarium, old_id: nybg.id, new_id: nybg.id
        )
      )
    end

    def test_merge_valid_source_into_non_personal_target
      login("mary")
      post(:create, params: { this: fundis.id, that: nybg.id })
      assert_redirected_to(
        observer_email_merge_request_path(
          type: :Herbarium, old_id: fundis.id, new_id: nybg.id
        )
      )
    end
  end
end

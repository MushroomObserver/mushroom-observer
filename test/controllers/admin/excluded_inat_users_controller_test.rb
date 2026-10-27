# frozen_string_literal: true

require("test_helper")

module Admin
  class ExcludedInatUsersControllerTest < FunctionalTestCase
    def test_index_lists_the_entries
      entry = ExcludedInatUser.create!(inat_login: "listed", reason: "Asked",
                                       user: users(:rolf))
      ContentPurge.create!(inat_login: "listed", image_count: 9)
      other = ExcludedInatUser.create!(inat_login: "other", inat_user_id: 5)
      make_admin("rolf")

      get(:index)

      assert_response(:success)
      assert_select("#excluded_inat_users a[href$='/people/listed']")
      assert_select("#excluded_inat_users td",
                    text: :content_purge_progress.l(deleted: 0, count: 9))
      assert_select("form[action='#{admin_excluded_inat_user_path(entry)}']")
      assert_select("#excluded_inat_users td", text: /other \(5\)/)
      purge_path = new_admin_excluded_inat_user_content_purge_path(other)
      assert_select("#excluded_inat_users a[href='#{purge_path}']")
    end

    def test_index_needs_admin_mode
      login("rolf")

      get(:index)

      assert_redirected_to("/")
    end

    def test_create
      make_admin("rolf")

      post(:create, params: { excluded_inat_user: { inat_login: "New_One",
                                                    reason: "" } })

      entry = ExcludedInatUser.find_by(inat_login: "new_one")
      assert_not_nil(entry, "Cannot find the ExcludedInatUser")
      assert_equal(users(:rolf), entry.user)
      assert_redirected_to(admin_excluded_inat_users_path)
    end

    def test_create_refuses_an_mo_users_login
      users(:mary).update!(inat_username: "mary_on_inat")
      make_admin("rolf")

      post(:create,
           params: { excluded_inat_user: { inat_login: "mary_on_inat" } })

      assert_unprocessable
      assert_not(ExcludedInatUser.exists?(inat_login: "mary_on_inat"))
      assert_flash_error
      assert_select("form#excluded_inat_user_form[data-turbo='true']")
    end

    def test_destroy
      entry = ExcludedInatUser.create!(inat_login: "listed")
      make_admin("rolf")

      delete(:destroy, params: { id: entry.id })

      assert_not(ExcludedInatUser.exists?(entry.id))
      assert_redirected_to(admin_excluded_inat_users_path)
    end
  end
end

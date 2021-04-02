# frozen_string_literal: true

require("test_helper")

# tests of Herbarium controller
module Herbaria
  class CuratorsControllerTest < FunctionalTestCase
    # ---------- Helpers ----------

    def nybg
      herbaria(:nybg_herbarium)
    end
    # ---------- Actions to Modify data: (create, update, destroy, etc.) -------

    def test_create
      assert(nybg.curators.include?(rolf))
      curator_count = nybg.curators.count

      login("rolf")
      post(:create, params: { id: nybg.id, add_curator: mary.login })
      assert_equal(curator_count + 1, nybg.reload.curators.count)
      assert_redirected_to(herbarium_path(nybg))
    end

    def test_create_no_login
      curator_count = nybg.curators.count

      post(:create, params: { id: nybg.id, add_curator: mary.login })
      assert_equal(curator_count, nybg.reload.curators.count)
    end

    def test_create_by_non_curator
      assert(nybg.curators.exclude?(mary))
      curator_count = nybg.curators.count

      login("mary")
      post(:create, params: { id: nybg.id, add_curator: mary.login })
      assert_equal(curator_count, nybg.reload.curators.count)
    end

    def test_create_nonuser_curator
      herbarium = herbaria(:rolf_herbarium)
      login("rolf")

      assert_no_difference(
        "herbarium.curators.count",
        "Curators should not change when trying to add non-user as curator"
      ) do
        post(:create, params: { id: herbarium.id, add_curator: "non-user" })
        herbarium.reload
      end
      assert_flash(
        /#{:show_herbarium_no_user.t(login: "non-user")}/,
        "Error should be flashed if trying to add non-user as curator"
      )
    end

    def test_destroy_by_curator
      assert(nybg.curator?(rolf))
      assert(nybg.curator?(roy))
      curator_count = nybg.curators.count

      login("rolf")
      delete(:destroy, params: { id: nybg.id, user: roy.id })

      assert_equal(curator_count - 1, nybg.reload.curators.count)
      assert_not(nybg.curator?(roy))
      assert_response(:redirect)
    end

    def test_destroy_by_admin
      assert_not(nybg.curator?(mary))
      assert(nybg.curator?(roy))
      curator_count = nybg.curators.count

      login("mary")
      make_admin("mary")
      delete(:destroy, params: { id: nybg.id, user: roy.id })

      assert_equal(curator_count - 1, nybg.reload.curators.count)
      assert_not(nybg.curator?(roy))
      assert_response(:redirect)
    end

    def test_destroy_no_login
      curator_count = nybg.curators.count
      delete(:destroy, params: { id: nybg.id, user: roy.id })

      assert_equal(curator_count, nybg.reload.curators.count)
      assert_response(:redirect)
    end

    def test_destroy_by_non_curator
      assert_not(nybg.curator?(mary))
      assert(nybg.curator?(roy))
      curator_count = nybg.curators.count

      login("mary")
      delete(:destroy, params: { id: nybg.id, user: roy.id })

      assert_equal(curator_count, nybg.reload.curators.count)
      assert_response(:redirect)
    end

    def test_destroy_no_user
      assert(nybg.curator?(rolf))
      curator_count = nybg.curators.count

      login("rolf")
      delete(:destroy, params: { id: nybg.id, user: nil })

      assert_equal(curator_count, nybg.reload.curators.count)
      assert_response(:redirect)
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module Herbaria
  # test of actions to request being a curator of a herbarium
  class CuratorRequestsControllerTest < FunctionalTestCase
    # ---------- Helpers ----------

    def nybg
      herbaria(:nybg_herbarium)
    end

    # ---------- Actions to Display forms -- (new, edit, etc.) -----------------

    def test_new
      login("mary")
      get(:new, params: { id: nybg.id })

      assert_select(
        "form[action^='#{herbaria_curator_requests_path(id: nybg)}']" \
        "[method='post']",
        { count: 1 },
        "Curator request should open a form that posts to " \
        "#{herbaria_curator_requests_path(id: nybg)}"
      )
    end

    def test_new_no_login
      get(:new, params: { id: nybg.id })
      assert_redirected_to(
        new_account_login_path,
        "Curator request by anonymous user should redirected to account login"
      )
    end

    def test_new_no_herbarium
      login("mary")
      get(:new)

      assert_redirected_to(
        herbaria_path,
        "Curator request without herbarium id should redirect to herbaria index"
      )
    end

    # ---------- Actions to Modify data: (create, update, destroy, etc.) -------

    def test_create
      email_count = ActionMailer::Base.deliveries.count
      login("mary")
      post(:create, params: { id: nybg.id, notes: "ZZYZX" })

      assert_redirected_to(herbarium_path(nybg))
      assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
      assert_match(/ZZYZX/, ActionMailer::Base.deliveries.last.to_s)
    end

    def test_create_no_login
      email_count = ActionMailer::Base.deliveries.count
      post(:create, params: { id: nybg.id })

      assert_equal(email_count, ActionMailer::Base.deliveries.count)
    end

    def test_create_no_herbarium
      email_count = ActionMailer::Base.deliveries.count
      login("mary")
      post(:create)

      assert_equal(email_count, ActionMailer::Base.deliveries.count)
    end
  end
end

# frozen_string_literal: true

require("test_helper")

# test of actions to request being a curator of a herbarium
class CuratorRequestsControllerTest < FunctionalTestCase
  # ---------- Helpers ----------

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

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  def test_new
    get(:new, params: { id: nybg.id })
    assert_redirected_to(
      account_login_path,
      "Curator request by anonymous user should redirected to account login"
    )

    login("mary")
    get(:new)
    assert_redirected_to(
      herbaria_path,
      "Curator request without herbarium id should redirect to index"
    )

    get(:new, id: nybg.id)
    assert_select(
      "form[action='#{curator_requests_path(id: nybg)}'][method='post']",
      { count: 1 },
      "Curator request should open a form that posts to " \
      "#{curator_requests_path(id: nybg)}"
    )
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  def test_create
    email_count = ActionMailer::Base.deliveries.count
    post(:create, params: { id: nybg.id })
    assert_equal(email_count, ActionMailer::Base.deliveries.count)

    login("mary")
    post(:create)
    assert_equal(email_count, ActionMailer::Base.deliveries.count)

    post(:create, params: { id: nybg.id, notes: "ZZYZX" })
    assert_response(:redirect)
    assert_equal(email_count + 1, ActionMailer::Base.deliveries.count)
    assert_match(/ZZYZX/, ActionMailer::Base.deliveries.last.to_s)
  end
end

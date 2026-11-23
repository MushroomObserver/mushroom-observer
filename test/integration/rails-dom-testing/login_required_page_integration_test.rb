# frozen_string_literal: true

require("test_helper")

# An anonymous visitor may read an observation at /obs/<id> and nowhere
# else: crawlers hold long lists of the other two forms. What those two
# serve is a page saying so, rather than the JSON string this used to
# render. nginx answers them from a static file when the request carries
# no session cookie; these cover the Rails side, which a stale cookie
# still reaches. That /obs/<id> stays open is pinned by
# `ObservationsControllerShowTest#test_show_no_login`.
class LoginRequiredPageIntegrationTest < IntegrationTestCase
  def test_anonymous_observations_path_serves_the_login_required_page
    get("/observations/#{observations(:minimal_unknown_obs).id}")

    assert_response(:forbidden)
    assert_select("a[href=?]", "/account/login/new")
    assert_select("a[href=?]", "/articles/46")
  end

  def test_anonymous_bare_id_path_serves_the_login_required_page
    get("/#{observations(:minimal_unknown_obs).id}")

    assert_response(:forbidden)
    assert_select("a[href=?]", "/account/login/new")
  end
end

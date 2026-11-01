# frozen_string_literal: true

require("test_helper")

class LocalesControllerTest < FunctionalTestCase
  def test_update_switches_locale_and_redirects_back
    @request.env["HTTP_REFERER"] = "http://test.host/observations/1"

    post(:update, params: { user_locale: "pt" })

    assert_equal("pt", I18n.locale.to_s)
    assert_equal("pt", session[:locale],
                 "The POST switch persists for the rest of the session")
    assert_redirected_to("http://test.host/observations/1")
  end

  def test_update_redirects_to_root_without_referer
    post(:update, params: { user_locale: "pt" })

    assert_redirected_to(root_path)
  end

  def test_update_does_not_persist_to_account
    user = users(:rolf)
    user.update(locale: "en")
    login(user.login)
    @request.env["HTTP_REFERER"] = "http://test.host/observations/1"

    post(:update, params: { user_locale: "pt" })

    assert_equal("en", user.reload.locale)
  end
end

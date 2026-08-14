# frozen_string_literal: true

require("test_helper")

class ApplicationControllerInternationalizationTest < FunctionalTestCase
  # Use TestController for these tests because we need a concrete controller
  # and ApplicationController is abstract and has no routes/actions to call
  tests TestController

  # Test that session_locale is used when no params or prefs locale exists
  def test_session_locale_used_when_no_params_or_prefs
    # Make a request without user_locale param and without logged-in user
    # but with session locale set
    get(:index, session: { locale: "pt" })

    # The session locale should have been used (lines 68-69 should execute)
    assert_equal("pt", I18n.locale.to_s)
  end

  # Test that session_locale is used when user has no locale preference
  def test_session_locale_used_with_user_without_locale_pref
    user = users(:rolf)
    user.update(locale: nil)

    login(user.login)

    # Request without user_locale param, user has no locale pref
    get(:index, session: { locale: "fr" })

    # The session locale should have been used
    assert_equal("fr", I18n.locale.to_s)
  end

  # Test that session_locale is used for ajax requests (prefs_locale skips ajax)
  def test_session_locale_used_for_ajax_request
    user = users(:rolf)
    user.update(locale: "pt")
    login(user.login)

    # Ajax request should skip prefs_locale and use session_locale
    get(:index, params: { controller: "ajax" }, session: { locale: "fr" })

    # The session locale should have been used instead of user's preference
    assert_equal("fr", I18n.locale.to_s)
  end
end

# TestController disables `autologin` (see `disable_filters`), so @user is
# always nil there -- these need a real controller to exercise the
# account-persistence question.
class ApplicationControllerInternationalizationAccountPersistenceTest <
      FunctionalTestCase
  tests ObservationsController

  # Issue #5074: a bare `?user_locale=` param (bookmark, crawler,
  # remembered URL) must switch the current request/session locale
  # but never silently overwrite the account's stored preference --
  # only the Preferences form does that.
  def test_params_locale_switches_request_but_not_account_preference
    user = users(:rolf)
    user.update(locale: "en")
    login(user.login)

    get(:index, params: { user_locale: "pt" })

    assert_equal("pt", I18n.locale.to_s)
    assert_equal("pt", session[:locale])
    assert_equal("en", user.reload.locale,
                 "A bare user_locale param must not change @user.locale")
  end
end

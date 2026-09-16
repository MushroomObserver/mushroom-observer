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

  # Issue #5314: a `?user_locale=` param on a GET (bookmark, crawler
  # index, legacy external link) is ignored entirely -- honoring it
  # switched unsuspecting visitors' sessions to another language. Only
  # the language picker's POST switches (see LocalesControllerTest).
  def test_get_user_locale_param_is_ignored
    user = users(:rolf)
    user.update(locale: "en")
    login(user.login)

    get(:index, params: { user_locale: "pt" })

    assert_equal("en", I18n.locale.to_s,
                 "A GET user_locale param must not switch the locale")
    assert_nil(session[:locale],
               "A GET user_locale param must not write the session")
    assert_equal("en", user.reload.locale)
  end

  # Issue #5074, second bug found in review: an explicit switch must
  # outrank the account's stored preference for the rest of the
  # session, or it reverts on the visitor's very next page load. The
  # switch itself is the picker's POST (LocalesControllerTest); its
  # session write is injected here since this controller has no POST
  # locale action.
  def test_explicit_switch_sticks_on_next_request_for_logged_in_user
    user = users(:rolf)
    user.update(locale: "en")
    login(user.login)

    get(:index, session: { locale: "pt" })
    assert_equal("pt", I18n.locale.to_s)

    # Follow-up request -- simulates the next page load after the
    # switcher POST's redirect back.
    get(:index)

    assert_equal("pt", I18n.locale.to_s,
                 "Explicit switch should outrank the unchanged account " \
                 "preference for the rest of the session")
    assert_equal("en", user.reload.locale)
  end

  # Same priority claim as the previous test, but as a single request
  # with session[:locale] injected directly, rather than relying on a
  # prior params_locale request to have set it -- pins the ordering
  # in specified_locale itself, independent of set_locale's own
  # session-write behavior.
  def test_session_locale_outranks_prefs_locale
    user = users(:rolf)
    user.update(locale: "en")
    login(user.login)

    get(:index, session: { locale: "pt" })

    assert_equal("pt", I18n.locale.to_s)
  end

  # No params, no prior switch -- the account's stored preference
  # should still win over the browser's Accept-Language header.
  def test_prefs_locale_outranks_browser_locale
    user = users(:rolf)
    user.update(locale: "pt")
    login(user.login)

    @request.env["HTTP_ACCEPT_LANGUAGE"] = "fr"
    get(:index)

    assert_equal("pt", I18n.locale.to_s)
  end

  # Nothing set at all (anonymous, no session, no account) -- falls
  # all the way through to the browser header.
  def test_browser_locale_used_as_last_resort
    @request.env["HTTP_ACCEPT_LANGUAGE"] = "fr"
    get(:index)

    assert_equal("fr", I18n.locale.to_s)
  end
end

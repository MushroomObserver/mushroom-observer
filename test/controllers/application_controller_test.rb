# frozen_string_literal: true

require("test_helper")

# Targeted coverage tests for the request-pipeline filter helpers
# defined directly on `ApplicationController`. Hosted on
# `InfoController` (a low-side-effect controller whose public
# `intro` action runs the full filter stack).
#
# `kick_out_robots` is covered by `InfoControllerTest` (allowed vs.
# unauthorized robot user-agents). `kick_out_excessive_traffic` /
# `is_cool?` are covered below by blocking a worker-specific test IP
# via `IpStats.add_blocked_ips`/`remove_blocked_ips`.
class ApplicationControllerTest < FunctionalTestCase
  tests InfoController

  # `change_theme_to` is invoked by `apply_user_theme_change`
  # (a before_action) when the request carries a `?user_theme=...`
  # param. Three branches:
  # (1) known theme + logged-in user persists it on the user,
  # (2) known theme + no user persists it in the session,
  # (3) unknown theme falls back to layout assignment.
  def test_user_theme_param_assigns_to_logged_in_user
    user = rolf
    theme = MO.themes.first
    original_theme = user.theme
    login("rolf")

    get(:intro, params: { user_theme: theme })

    assert_response(:success)
    assert_equal(theme, user.reload.theme,
                 "Logged-in user's theme should persist to the model")
  ensure
    user&.update_column(:theme, original_theme)
  end

  def test_user_theme_param_logged_out_persists_in_session
    theme = MO.themes.first

    get(:intro, params: { user_theme: theme })

    assert_response(:success)
    assert_equal(theme, session[:theme],
                 "Logged-out theme change should land in session")
  end

  def test_user_theme_param_unknown_value_sets_layout_session
    # An unknown theme name lands in `session[:layout]`; the next
    # render's Phlex layout-picker (`Views::FullPageBase#around_template`)
    # reads it. Anything that isn't `"printable"` falls back to the
    # default Application layout, so the request still renders.
    get(:intro, params: { user_theme: "BOGUS_LAYOUT" })

    assert_response(:success)
    assert_equal("BOGUS_LAYOUT", session[:layout],
                 "Unknown theme should be stored on session[:layout]")
  end

  # `fix_bad_domains` redirects GETs to `MO.http_domain` when the
  # request host matches one of `MO.bad_domains` (configured in
  # `test.rb` as `www.mushroomobserver.org`). Covers L206 in
  # `application_controller.rb`.
  def test_fix_bad_domains_redirects_when_host_matches
    @request.host = "www.mushroomobserver.org"

    get(:intro)

    assert_redirected_to(/#{Regexp.escape(MO.http_domain)}/,
                         "GET against a bad domain should redirect")
  end

  # `reset_user_group_cache` guards against the same landmine pattern
  # fixed for Textile (#4741): UserGroup.all_users/reviewers/one_user
  # memoize per request (Thread.current[...]), which survives between
  # sequential requests pooled onto the same thread unless reset. A
  # request that never touches these must not inherit a prior
  # request's memoized groups.
  def test_reset_user_group_cache_clears_stale_state_before_next_request
    UserGroup.all_users
    UserGroup.reviewers
    UserGroup.one_user(users(:rolf))

    get(:intro)

    assert_response(:success)
    calls = 0
    UserGroup.stub(:find_by_name, lambda { |name|
      calls += 1
      UserGroup.find_by(name: name)
    }) do
      UserGroup.all_users
      UserGroup.reviewers
      UserGroup.one_user(users(:rolf))
    end
    assert_equal(3, calls,
                 "UserGroup's per-request memo should be reset before " \
                 "every request, not leak state from a prior one")
  end

  # `reset_textile_cache` guards against a landmine bug: Textile's
  # name-lookup cache is thread-local (isolated across concurrent
  # requests), but without a per-request reset it survives between
  # sequential requests pooled onto the same thread -- a page that
  # primes the cache (`Textile.register_name`) would otherwise leak
  # its abbreviations into whatever request runs next on that thread.
  # See #3589.
  def test_reset_textile_cache_clears_stale_state_before_next_request
    # Simulate a prior request/page having primed the cache and left
    # it dirty (no request boundary has run in this test process yet).
    Textile.register_name(names(:coprinus_comatus))
    assert_not_empty(Textile.name_lookup,
                     "Textile.register_name should have primed the cache")

    get(:intro)

    assert_response(:success)
    assert_empty(Textile.name_lookup,
                 "Textile's name-lookup cache should be reset before " \
                 "every request, not leak state from a prior one")
  end

  # `extra_gc` just calls `ObjectSpace.garbage_collect`. Wired in
  # as an `around_action` on some debug-only endpoints; not
  # routinely exercised. Cover by calling directly on a controller
  # instance.
  def test_extra_gc_invokes_garbage_collect
    @controller.extra_gc # should not raise
  end

  # `default_thumbnail_size` returns the logged-in user's
  # preference if set, else the session value, else "thumbnail".
  def test_default_thumbnail_size_returns_user_preference
    user = rolf
    original = user.thumbnail_size
    user.update!(thumbnail_size: "small")
    login("rolf")
    get(:intro)

    assert_equal("small", @controller.default_thumbnail_size)
  ensure
    user&.update_column(:thumbnail_size, original)
  end

  def test_default_thumbnail_size_falls_back_to_session
    get(:intro)
    session[:thumbnail_size] = "small"

    assert_equal("small", @controller.default_thumbnail_size)
  end

  # `default_thumbnail_size_set` persists to the user when one is
  # logged in AND the new value differs from the current
  # preference; otherwise it sets the session value.
  def test_default_thumbnail_size_set_persists_to_logged_in_user
    user = rolf
    original = user.thumbnail_size
    user.update!(thumbnail_size: "thumbnail")
    login("rolf")
    get(:intro)

    @controller.default_thumbnail_size_set("small")

    assert_equal("small", user.reload.thumbnail_size)
  ensure
    user&.update_column(:thumbnail_size, original)
  end

  def test_default_thumbnail_size_set_falls_back_to_session
    get(:intro)

    @controller.default_thumbnail_size_set("small")

    assert_equal("small", session[:thumbnail_size])
  end

  # `kick_out_excessive_traffic` renders 429 when `is_cool?` returns
  # false: the request IP is blocked and neither allow-list branch
  # (`account#login`, logged-in session) applies.
  def test_kick_out_excessive_traffic_blocks_blocked_ip
    ip = "203.0.113.5"
    IpStats.add_blocked_ips([ip])
    IpStats.reset!
    @request.remote_ip = ip

    get(:intro)

    assert_response(429) # rubocop:disable Rails/HttpStatus
  ensure
    IpStats.remove_blocked_ips([ip])
    IpStats.reset!
  end

  # `is_cool?` allow-lists `account#login` by name so a blocked IP can
  # still reach the login page.
  def test_is_cool_allows_account_login_action_when_blocked
    ip = "203.0.113.6"
    IpStats.add_blocked_ips([ip])
    IpStats.reset!
    get(:intro)
    @request.remote_ip = ip
    @controller.params = { controller: "account", action: "login" }

    assert(@controller.is_cool?)
  ensure
    IpStats.remove_blocked_ips([ip])
    IpStats.reset!
  end

  # `try_user_autologin`'s MRTG branch sets `@user` unconditionally
  # (no `user_verified_and_allowed?` check), so a blocked MRTG "user"
  # is the one way `block_suspended_users` ever sees a blocked
  # `@user` - every other login path (session, autologin cookie)
  # rejects blocked users before `@user` gets assigned.
  def test_mrtg_autologin_blocked_renders_deleted_message
    mrtg_user = User.create!(
      id: 164_054, login: "mrtg", email: "mrtg@example.com",
      password: "blah!", password_confirmation: "blah!",
      blocked: true
    )

    Rails.env.stub(:production?, true) do
      @request.remote_ip = "127.0.0.1"
      get(:intro)
    end

    assert_equal("Your account has been deleted.", @response.body)
  ensure
    mrtg_user&.destroy
  end

  # `is_cool?` also allow-lists a blocked IP that already has a
  # logged-in session (`session[:user_id].present?`).
  def test_is_cool_allows_blocked_ip_with_logged_in_session
    ip = "203.0.113.7"
    IpStats.add_blocked_ips([ip])
    IpStats.reset!
    login("rolf")
    get(:intro)
    @request.remote_ip = ip

    assert(@controller.is_cool?)
  ensure
    IpStats.remove_blocked_ips([ip])
    IpStats.reset!
  end

  # `ApplicationController::Indexes#index_display_opts`'s base
  # implementation merges into an empty hash -- every controller with
  # an index overrides it, so InfoController (no index action) is the
  # only way to reach the base method itself.
  def test_index_display_opts_base_implementation_merges_extra_opts
    opts = @controller.send(:index_display_opts, { foo: 1 }, nil)

    assert_equal({ foo: 1 }, opts)
  end

  # `paginator_number`'s rescue guards against an unparseable page
  # value -- inject a value that raises on `#to_s` to exercise it
  # directly, since ordinary HTTP params (String/Array/Hash) don't.
  def test_paginator_number_rescues_unparseable_value
    poison = Object.new
    def poison.to_s
      raise(StandardError.new("boom"))
    end
    @controller.define_singleton_method(:params) { { page: poison } }

    assert_equal(1, @controller.send(:paginator_number, :page))
  end

  # `index_filter`'s explicit `model:` argument guards against a
  # stale/mismatched ambient current_query (session[:query_record]
  # left over from browsing a different model) leaking that model's
  # filter attrs onto an unrelated index link -- unlike q_param,
  # which stays safe because it tags the mismatched query with
  # :model for the receiving page to reconcile. Reproduces the
  # scenario directly: an Observations query left in the session,
  # then a page asking for a Name filter without one set for it.
  def test_index_filter_rejects_mismatched_ambient_query
    login("rolf")
    get(:intro)
    observation_query = Query.lookup_and_save(:Observation,
                                              by_users: [rolf.id])
    @controller.store_query_in_session(observation_query)

    assert_nil(@controller.index_filter(:Name))
  end

  def test_index_filter_returns_filter_for_matching_ambient_query
    login("rolf")
    get(:intro)
    name_query = Query.lookup_and_save(:Name, by_users: [rolf.id])
    @controller.store_query_in_session(name_query)

    assert_equal({ by_user: rolf.id }, @controller.index_filter(:Name))
  end

  def test_index_filter_with_explicit_query_checks_model_too
    login("rolf")
    get(:intro)
    observation_query = Query.lookup_and_save(:Observation,
                                              by_users: [rolf.id])

    assert_nil(@controller.index_filter(:Name, observation_query))
    assert_equal(
      { by_user: rolf.id },
      @controller.index_filter(:Observation, observation_query)
    )
  end
end

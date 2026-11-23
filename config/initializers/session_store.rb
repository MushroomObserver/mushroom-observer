# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# `key` is matched by name in config/etc/nginx.conf, which serves the
# login-required page to a request that carries no session cookie.
MushroomObserver::Application.config.session_store(
  :cookie_store,
  key: "_mushroom-observer_session_3.1",
  same_site: :lax
)

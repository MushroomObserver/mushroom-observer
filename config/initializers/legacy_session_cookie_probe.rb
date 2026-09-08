# frozen_string_literal: true

# Companion to session_cookie_digest_rotator.rb. That rotation has no
# externally visible signal for whether it's still doing anything --
# ActiveSupport::Messages::Rotator's on_rotation callback is consumed
# entirely inside Rails' private cookie-jar code. This probe is
# independent of that decrypt path (a bug here can't affect a live
# session): on every request it tries the session cookie against ONLY
# the pre-flip secret and records a timestamp on a hit. Once
# SessionCookieDigestMigration::CACHE_KEY has gone unwritten for a few
# months, no browser still holds a pre-flip cookie and both this file
# and session_cookie_digest_rotator.rb can be deleted.
class LegacySessionCookieProbe
  SESSION_COOKIE_KEY = "_mushroom-observer_session_3.1"

  def initialize(app)
    @app = app
  end

  def call(env)
    record_legacy_cookie_sighting(env)
    @app.call(env)
  end

  private

  def record_legacy_cookie_sighting(env)
    raw_value = Rack::Request.new(env).cookies[SESSION_COOKIE_KEY]
    return unless raw_value

    SessionCookieDigestMigration.legacy_encryptor.decrypt_and_verify(raw_value)
    Rails.cache.write(SessionCookieDigestMigration::CACHE_KEY, Time.current,
                      expires_in: 1.year)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage,
         ActiveSupport::MessageVerifier::InvalidSignature
    nil
  rescue StandardError => e
    Rails.logger.error("LegacySessionCookieProbe: #{e.class}: #{e.message}")
  end
end

Rails.application.config.middleware.use(LegacySessionCookieProbe)

# frozen_string_literal: true

require("test_helper")

# config/initializers/legacy_session_cookie_probe.rb records when the
# session cookie's legacy (pre-flip) secret is still needed, so we know
# when it is safe to delete the rotator.
class LegacySessionCookieProbeTest < UnitTestCase
  def test_legacy_cookie_records_a_sighting
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      call_probe(cookie_header: legacy_cookie_header)

      assert_kind_of(
        Time, Rails.cache.read(SessionCookieDigestMigration::CACHE_KEY)
      )
    end
  end

  def test_current_format_cookie_records_nothing
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      call_probe(cookie_header: current_cookie_header)

      assert_nil(Rails.cache.read(SessionCookieDigestMigration::CACHE_KEY))
    end
  end

  def test_no_cookie_records_nothing
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      call_probe(cookie_header: nil)

      assert_nil(Rails.cache.read(SessionCookieDigestMigration::CACHE_KEY))
    end
  end

  def test_request_still_reaches_the_app_regardless
    status, = call_probe(cookie_header: legacy_cookie_header)

    assert_equal(200, status)
  end

  private

  def call_probe(cookie_header:)
    downstream = ->(_env) { [200, {}, ["ok"]] }
    env = Rack::MockRequest.env_for("/")
    env["HTTP_COOKIE"] = cookie_header if cookie_header

    LegacySessionCookieProbe.new(downstream).call(env)
  end

  def legacy_cookie_header
    secret, sign_secret = SessionCookieDigestMigration.legacy_secrets
    build_cookie_header(secret, sign_secret)
  end

  def current_cookie_header
    dispatch = Rails.application.config.action_dispatch
    key_generator = Rails.application.key_generator
    key_len = ActiveSupport::MessageEncryptor.key_len("aes-256-cbc")
    secret = key_generator.generate_key(dispatch.encrypted_cookie_salt, key_len)
    sign_secret =
      key_generator.generate_key(dispatch.encrypted_signed_cookie_salt)
    build_cookie_header(secret, sign_secret)
  end

  def build_cookie_header(secret, sign_secret)
    encryptor = ActiveSupport::MessageEncryptor.new(
      secret, sign_secret, cipher: "aes-256-cbc",
                           serializer: ActiveSupport::MessageEncryptor::NullSerializer
    )
    value = encryptor.encrypt_and_sign(Marshal.dump({ "user_id" => 42 }))
    "#{LegacySessionCookieProbe::SESSION_COOKIE_KEY}=" \
      "#{Rack::Utils.escape(value)}"
  end
end

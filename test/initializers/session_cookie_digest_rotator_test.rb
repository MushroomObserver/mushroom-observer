# frozen_string_literal: true

require("test_helper")

# config/initializers/session_cookie_digest_rotator.rb registers a
# rotation so a session cookie encrypted under the pre-SHA256
# key_generator_hash_digest_class still decrypts. MO has no
# config.load_defaults call, so the session cookie goes through the
# legacy (non-GCM) cipher path -- this pins that the rotation targets
# the salts that path uses.
class SessionCookieDigestRotatorTest < UnitTestCase
  def test_digest_class_is_sha256
    assert_equal(
      OpenSSL::Digest::SHA256,
      Rails.application.config.active_support.key_generator_hash_digest_class
    )
  end

  def test_pre_flip_cookie_still_decrypts_through_the_live_jar
    old_secret, old_sign_secret = legacy_derived_secrets

    encrypted_jar = build_encrypted_jar_with(
      legacy_encryptor(old_secret, old_sign_secret).encrypt_and_sign(
        Marshal.dump({ "user_id" => 42 })
      )
    )

    assert_equal({ "user_id" => 42 }, encrypted_jar["_test_cookie"])
  end

  def test_fresh_writes_use_the_new_digest_not_the_old_secret
    old_secret, old_sign_secret = legacy_derived_secrets
    new_secret, new_sign_secret = current_derived_secrets

    assert_not_equal(old_secret, new_secret)

    new_payload = legacy_encryptor(new_secret, new_sign_secret).
                  encrypt_and_sign("x")

    assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
      legacy_encryptor(old_secret, old_sign_secret).
        decrypt_and_verify(new_payload)
    end
  end

  private

  def key_len
    ActiveSupport::MessageEncryptor.key_len("aes-256-cbc")
  end

  def legacy_derived_secrets
    key_generator = ActiveSupport::KeyGenerator.new(
      Rails.application.secret_key_base,
      iterations: 1000, hash_digest_class: OpenSSL::Digest::SHA1
    )
    derive_secrets(key_generator)
  end

  def current_derived_secrets
    derive_secrets(Rails.application.key_generator)
  end

  def derive_secrets(key_generator)
    dispatch = Rails.application.config.action_dispatch
    [
      key_generator.generate_key(dispatch.encrypted_cookie_salt, key_len),
      key_generator.generate_key(dispatch.encrypted_signed_cookie_salt)
    ]
  end

  def legacy_encryptor(secret, sign_secret)
    ActiveSupport::MessageEncryptor.new(
      secret, sign_secret, cipher: "aes-256-cbc",
                           serializer: ActiveSupport::MessageEncryptor::NullSerializer
    )
  end

  def build_encrypted_jar_with(cookie_value)
    env = Rack::MockRequest.env_for("/").merge(Rails.application.env_config)
    request = ActionDispatch::Request.new(env)
    jar = ActionDispatch::Cookies::CookieJar.build(request, {})
    request.cookie_jar = jar
    jar["_test_cookie"] = cookie_value

    ActionDispatch::Cookies::EncryptedKeyRotatingCookieJar.new(jar)
  end
end

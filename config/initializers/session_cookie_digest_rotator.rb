# frozen_string_literal: true

# Session-cookie digest migration: the SHA1 -> SHA256
# key_generator_hash_digest_class flip in new_framework_defaults_7_0.rb.
# The session cookie is the only thing this touches -- see the PR
# description for what was checked to confirm that.
#
# The pre-flip session cookie was encrypted via the legacy, non-GCM
# cipher path (encrypted_cookie_salt + encrypted_signed_cookie_salt,
# "aes-256-cbc"), not authenticated_encrypted_cookie_salt -- this
# derives the rotation secret from that same pair of salts, mirroring
# ActionDispatch::Cookies::EncryptedKeyRotatingCookieJar's derivation.
# load_defaults(7.2) separately turns on
# use_authenticated_cookie_encryption, switching new cookies to the
# GCM cipher -- a second transition layered on top of this one.
# Rails registers a separate upgrade rotation for that transition
# alongside this file's, so a pre-flip cookie still decrypts (see
# test/initializers/session_cookie_digest_rotator_test.rb).
#
# legacy_session_cookie_probe.rb is the companion file that tells us
# when it's safe to delete this one.
module SessionCookieDigestMigration
  CACHE_KEY = "legacy_session_cookie_last_seen_at"

  module_function

  def legacy_secrets
    key_generator = ActiveSupport::KeyGenerator.new(
      Rails.application.secret_key_base,
      iterations: 1000, hash_digest_class: OpenSSL::Digest::SHA1
    )
    dispatch = Rails.application.config.action_dispatch
    key_len = ActiveSupport::MessageEncryptor.key_len("aes-256-cbc")
    [
      key_generator.generate_key(dispatch.encrypted_cookie_salt, key_len),
      key_generator.generate_key(dispatch.encrypted_signed_cookie_salt)
    ]
  end

  def legacy_encryptor
    secret, sign_secret = legacy_secrets
    ActiveSupport::MessageEncryptor.new(
      secret, sign_secret, cipher: "aes-256-cbc",
                           serializer: ActiveSupport::MessageEncryptor::NullSerializer
    )
  end
end

Rails.application.config.after_initialize do
  secret, sign_secret = SessionCookieDigestMigration.legacy_secrets
  Rails.application.config.action_dispatch.cookies_rotations.rotate(
    :encrypted, secret, sign_secret, cipher: "aes-256-cbc"
  )
end

# frozen_string_literal: true

# Session-cookie digest migration: the SHA1 -> SHA256
# key_generator_hash_digest_class flip in new_framework_defaults_7_0.rb.
# The session cookie is the only thing this touches -- see the PR
# description for what was checked to confirm that.
#
# MO does not call `config.load_defaults`, so
# action_dispatch.use_authenticated_cookie_encryption is still false (its
# absolute framework default) -- the session cookie goes through the
# legacy, non-GCM cipher path (encrypted_cookie_salt +
# encrypted_signed_cookie_salt, "aes-256-cbc"), not
# authenticated_encrypted_cookie_salt. Deriving the rotation secret with
# the wrong salt would silently fail to decrypt any pre-flip cookie --
# see ActionDispatch::Cookies::EncryptedKeyRotatingCookieJar for the
# derivation this mirrors.
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

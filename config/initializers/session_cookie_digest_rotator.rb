# frozen_string_literal: true

# Rotator for the SHA1 -> SHA256 key_generator_hash_digest_class flip in
# new_framework_defaults_7_0.rb. Without this, every session cookie
# encrypted under the old digest fails to decrypt the moment the flip
# deploys, logging every signed-in user out at once.
#
# MO does not call `config.load_defaults`, so
# action_dispatch.use_authenticated_cookie_encryption is still false (its
# absolute framework default) -- the session cookie goes through the
# legacy, non-GCM cipher path (encrypted_cookie_salt +
# encrypted_signed_cookie_salt, "aes-256-cbc"), not
# authenticated_encrypted_cookie_salt. Registering the rotation with the
# wrong salt would silently fail to decrypt any pre-flip cookie -- see
# ActionDispatch::Cookies::EncryptedKeyRotatingCookieJar for the exact
# derivation this mirrors.
Rails.application.config.after_initialize do
  old_key_generator = ActiveSupport::KeyGenerator.new(
    Rails.application.secret_key_base,
    iterations: 1000,
    hash_digest_class: OpenSSL::Digest::SHA1
  )
  key_len = ActiveSupport::MessageEncryptor.key_len("aes-256-cbc")

  old_secret = old_key_generator.generate_key(
    Rails.application.config.action_dispatch.encrypted_cookie_salt, key_len
  )
  old_sign_secret = old_key_generator.generate_key(
    Rails.application.config.action_dispatch.encrypted_signed_cookie_salt
  )

  Rails.application.config.action_dispatch.cookies_rotations.rotate(
    :encrypted, old_secret, old_sign_secret, cipher: "aes-256-cbc"
  )
end

# frozen_string_literal: true

class Token
  attr_accessor :hash

  def initialize(hash = {})
    @hash = hash
  end

  def encrypt_to_header
    token_json = JSON.generate(@hash)
    Token.crypt.encrypt_and_sign(token_json)
  end

  def self.decrypt_from_header(auth_header)
    token = Token.crypt.decrypt_and_verify(auth_header)
    hash = JSON.parse(token)
    new(hash)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def self.crypt
    @@crypt ||= ActiveSupport::MessageEncryptor.new(
      Rails.application.credentials.secret_key_base.byteslice(0..31)
    )
  end
end

# frozen_string_literal: true

# VerifyAPIKey Email
class QueuedEmail
  class VerifyAPIKey < QueuedEmail
    def api_key
      get_object(:api_key, ::APIKey)
    end

    def self.create_email(for_user, user, api_key)
      raise("Missing api_key!") unless api_key

      result = create(user, for_user)
      result.add_integer(:api_key, api_key.id)
      result.finish
      result
    end

    def deliver_email
      # Make sure it hasn't been deleted since email was queued.
      return unless key = api_key

      VerifyAPIKeyMailer.build(for_user, user, key).deliver_now
    end
  end
end

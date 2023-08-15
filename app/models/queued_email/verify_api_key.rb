# frozen_string_literal: true

# VerifyAPIKey Email
class QueuedEmail
  class VerifyAPIKey < QueuedEmail
    def api_key
      get_object(:api_key, ::APIKey)
    end

    def self.create_email(user, app, api_key)
      raise("Missing api_key!") unless api_key

      # arguments are: sender = to_user = app, recipient = user
      result = create(app, user)
      result.add_integer(:api_key, api_key.id)
      result.finish
      result
    end

    def deliver_email
      # Make sure it hasn't been deleted since email was queued.
      return unless key = api_key

      VerifyAPIKeyMailer.build(to_user, user, key).deliver_now
    end
  end
end

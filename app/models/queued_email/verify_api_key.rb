# frozen_string_literal: true

# VerifyAPIKey Email
class QueuedEmail
  class VerifyAPIKey < QueuedEmail
    def api_key
      get_object(:api_key, ::APIKey)
    end

    def self.create_email(for_user = nil, user, api_key)
      raise("Missing api_key!") unless api_key

      result = create(::User.admin, user)

      # for_user ||= user
      # if other_user
      result.add_integer(:for_user, user.id) if for_user
      # else
      #   result.add_integer(:other_user, recipient.id)
      # end

      result.add_integer(:api_key, api_key.id)
      result.finish
      result
    end

    def deliver_email
      # Make sure it hasn't been deleted since email was queued.
      return unless api_key

      VerifyAPIKeyMailer.build(for_user, user, api_key).deliver_now
    end
  end
end

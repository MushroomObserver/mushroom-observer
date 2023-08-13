# frozen_string_literal: true

# VerifyAPIKey Email
class QueuedEmail
  class VerifyAPIKey < QueuedEmail
    def user
      get_object(:user, ::User)
    end

    def for_user
      get_object(:for_user, ::User)
    end

    def api_key
      get_object(:api_key, ::APIKey)
    end

    def self.create_email(user, for_user, api_key)
      # result = create(sender, recipient)
      # raise("Missing object!") unless object

      # result.add_integer(:user, object.id)
      # result.add_string(:obj_type, object.type_tag.to_s)
      # result.add_string(:subject, subject)
      # result.set_note(message)
      # result.finish
      # result
    end

    def deliver_email
      # Make sure it hasn't been deleted since email was queued.
      return unless api_key

      VerifyAPIKeyMailer.build(user, other_user, api_key).deliver_now
    end
  end
end

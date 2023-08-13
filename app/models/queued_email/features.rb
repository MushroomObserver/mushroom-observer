# frozen_string_literal: true

# Features Email
module QueuedEmail
  class Features < QueuedEmail
    def content
      get_note
    end

    def self.create_email(receiver, content)
      result = create(nil, receiver)
      raise("Missing content!") unless content

      result.set_note(content)
      result.finish
      result
    end

    def deliver_email
      return if to_user.no_emails
      return unless to_user.email_general_feature # Make sure it hasn't changed

      FeaturesMailer.build(to_user, content).deliver_now
    end
  end
end

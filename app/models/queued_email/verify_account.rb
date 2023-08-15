# frozen_string_literal: true

# Verify Account Email
class QueuedEmail
  class VerifyAccount < QueuedEmail
    def self.create_email(user)
      result = create(nil, user)

      result.finish
      result
    end

    def deliver_email
      VerifyAccountMailer.build(to_user).deliver_now
    end
  end
end

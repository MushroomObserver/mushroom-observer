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

    # In this case we want current_user for
    # AbstractModel#set_user_and_autolog to remain nil
    def current_user
      nil
    end
  end
end

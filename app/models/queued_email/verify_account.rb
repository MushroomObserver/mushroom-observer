# frozen_string_literal: true

# Verify Account Email
class QueuedEmail
  class VerifyAccount < QueuedEmail
    def self.create_email(user)
      result = create(nil, user)

      result.finish
      result
    end

    # Override to enable raise_delivery_errors so we can detect SMTP failures.
    # If delivery fails, return false so the email stays in queue for retry.
    def deliver_email
      old_setting = ActionMailer::Base.raise_delivery_errors
      ActionMailer::Base.raise_delivery_errors = true
      VerifyAccountMailer.build(to_user).deliver_now
    rescue StandardError => e
      Rails.logger.error("VerifyAccount email failed: #{e.message}")
      false
    ensure
      ActionMailer::Base.raise_delivery_errors = old_setting
    end

    # In this case we want current_user for
    # AbstractModel#set_user_and_autolog to remain nil
    def current_user
      nil
    end
  end
end

# frozen_string_literal: true

# Password Email
class QueuedEmail
  class Password < QueuedEmail
    def password
      get_string(:password)
    end

    def self.create_email(user, password)
      raise("Missing password!") unless password

      result = create(user)

      result.add_string(:password, password)
      result.finish
      result
    end

    def deliver_email
      # Make sure it hasn't been deleted since email was queued.
      return unless password

      PasswordMailer.build(user, password).deliver_now
    end
  end
end

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

    # AbstractModel#set_user_and_autolog will fill in user with User.current
    # if we aren't careful.  This may be the simplest (and cheesiest) way to
    # ensure user stays nil.  This should override the user column.
    def user
      nil
    end
  end
end

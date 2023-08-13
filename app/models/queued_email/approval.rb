# frozen_string_literal: true

# Approval notification
class QueuedEmail
  class Approval < QueuedEmail
    def subject
      get_string(:subject)
    end

    def content
      get_note
    end

    def self.find_or_create_email(user, subject, content)
      email = create(User.admin, user)
      email.add_string(:subject, subject.truncate_bytes(100))
      email.set_note(content)
      email.finish
      email
    end

    def deliver_email
      ApprovalMailer.build(to_user, subject, content).deliver_now
    end
  end
end

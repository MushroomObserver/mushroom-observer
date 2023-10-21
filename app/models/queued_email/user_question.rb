# frozen_string_literal: true

# User to User Questions
class QueuedEmail
  class UserQuestion < QueuedEmail
    def subject
      get_string(:subject)
    end

    def content
      get_note
    end

    def self.create_email(sender, user, subject, content)
      raise("Missing subject!") unless subject
      raise("Missing content!") unless content

      result = create(sender, user)
      result.add_string(:subject, subject)
      result.set_note(content)
      result.finish
      result
    end

    def deliver_email
      UserQuestionMailer.build(user, to_user, subject, content).deliver_now
    end
  end
end

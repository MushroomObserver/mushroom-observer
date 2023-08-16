# frozen_string_literal: true

# Ask Webmaster a Question Email
class QueuedEmail
  class Webmaster < QueuedEmail
    def sender_email
      get_string(:sender_email)
    end

    def subject
      get_string(:subject)
    end

    def content
      get_note
    end

    def self.create_email(sender_email:, content:, subject: nil)
      raise("Missing email address!") unless sender_email
      raise("Missing content!") unless content

      result = create(nil, nil)
      result.add_string(:sender_email, sender_email)
      result.add_string(:subject, subject) if subject
      result.set_note(content)
      result.finish
      result
    end

    def deliver_email
      WebmasterMailer.build(sender_email: sender_email, content: content,
                            subject: subject).deliver_now
    end
  end
end

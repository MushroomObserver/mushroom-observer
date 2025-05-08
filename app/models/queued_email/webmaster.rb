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

    def self.create_email(user, content:, sender_email: nil, subject: nil)
      sender_email = user.email if user && sender_email.nil?
      raise("Missing email address!") unless sender_email
      raise("Missing content!") unless content

      content = prepend_user(user, content)
      result = create(user, nil)
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

    ##########

    def self.prepend_user(user, content)
      return content if user.blank?

      "(from User ##{user.id} #{user.name}(#{user.login}))\n#{content}"
    end

    private_class_method :prepend_user
  end
end

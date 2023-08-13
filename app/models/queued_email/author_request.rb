# frozen_string_literal: true

# Request to be the author of an object, usually a Description
class QueuedEmail
  class AuthorRequest < QueuedEmail
    def obj_id
      get_integer(:obj_id)
    end

    def obj_type
      get_string(:obj_type)
    end

    def subject
      get_string(:subject)
    end

    def content
      get_note
    end

    def self.create_email(sender, recipient, object, subject, message)
      result = create(sender, recipient)
      raise("Missing object!") unless object

      result.add_integer(:obj_id, object.id)
      result.add_string(:obj_type, object.type_tag.to_s)
      result.add_string(:subject, subject)
      result.set_note(message)
      result.finish
      result
    end

    def deliver_email
      # Make sure it hasn't been deleted since email was queued.
      return unless obj_id && obj_type && subject && content

      object = AbstractModel.find_object(obj_type, obj_id)

      AuthorMailer.build(user, to_user, object, subject, content).deliver_now
    end
  end
end

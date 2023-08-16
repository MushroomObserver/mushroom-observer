# frozen_string_literal: true

# Image Commercial Inquiry Email
class QueuedEmail
  class CommercialInquiry < QueuedEmail
    def image
      get_object(:image, ::Image)
    end

    def content
      get_note
    end

    def self.create_email(sender, image, content)
      raise("Missing image!") unless image
      raise("Missing content!") unless content

      result = create(sender, image.user)
      result.add_integer(:image, image.id)
      result.set_note(content)
      result.finish
      result
    end

    def deliver_email
      CommercialInquiryMailer.build(user, image, content).deliver_now
    end
  end
end

# frozen_string_literal: true

# Add HerbariumRecord Not Curator Email
class QueuedEmail
  class AddHerbariumRecordNotCurator < QueuedEmail
    def herbarium_record
      get_object(:herbarium_record, ::HerbariumRecord)
    end

    def self.create_email(sender, recipient, herbarium_record)
      result = create(sender, recipient)
      raise("Missing herbarium_record!") unless herbarium_record

      result.add_integer(:herbarium_record, herbarium_record.id)
      result.finish
      result
    end

    def deliver_email
      # Make sure it hasn't been deleted since email was queued.
      return unless herbarium_record

      AddHerbariumRecordEmail.build(user, to_user, herbarium_record).deliver_now
    end
  end
end

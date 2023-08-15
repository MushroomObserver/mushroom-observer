# frozen_string_literal: true

# Admin Email
class QueuedEmail
  class ProjectAdminRequest < QueuedEmail
    def project
      get_object(:project, ::Project)
    end

    def subject
      get_string(:subject)
    end

    def content
      get_note
    end

    def self.create_email(sender, recipient, project, subject, content)
      raise("Missing project!") unless project
      raise("Missing content!") unless content

      result = create(sender, recipient)
      result.add_integer(:project, project.id)
      result.add_string(subject)
      result.set_note(content)
      result.finish
      result
    end

    def deliver_email
      # Make sure it hasn't been deleted since email was queued.
      return unless herbarium_record

      ProjectAdminRequestMailer.build(user, to_user, project,
                                      subject, content).deliver_now
    end
  end
end

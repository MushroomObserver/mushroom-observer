# frozen_string_literal: true

# Ask Observer a Question Emails
class QueuedEmail
  class ObserverQuestion < QueuedEmail
    def observation
      get_object(:observation, ::Observation)
    end

    def question
      get_note
    end

    def self.create_email(sender, observation, question)
      raise("Missing observation!") unless observation
      raise("Missing question!") unless question

      result = create(sender, user)
      result.add_integer(:observation, observation.id)
      result.set_note(question)
      result.finish
      result
    end

    def deliver_email
      ObserverQuestionMailer.build(sender, observation, question).deliver_now
    end
  end
end

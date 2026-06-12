# frozen_string_literal: true

module Views::Controllers::Descriptions::AuthorRequests
  # Form to request authorship of a description. Sends an email to the
  # authors/reviewers. Posts to `Descriptions::AuthorRequestsController`.
  class Form < ::Components::ApplicationForm
    def initialize(model, object:, action:, **)
      @object = object
      super(model, action: action, **)
    end

    def view_template
      render_note
      render_subject_field
      render_message_field
      submit(:SEND.t, center: true)
    end

    private

    def render_note
      p { :author_request_note.tp }
    end

    def render_subject_field
      text_field(:subject, label: "#{:request_subject.t}:",
                           data: { autofocus: true })
    end

    def render_message_field
      textarea_field(:message, label: "#{:request_message.t}:", rows: 10)
    end
  end
end

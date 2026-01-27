# frozen_string_literal: true

# Form for sending a question to another user.
# Allows users to contact each other through the site.
class Components::UserQuestionForm < Components::ApplicationForm
  def initialize(model, target:, subject: nil, message: nil, **)
    @target = target
    @subject = subject
    @message = message
    super(model, **)
  end

  def view_template
    super do
      p { :ask_user_question_label.t(user: @target.legal_name) }
      br
      render_subject_field
      render_message_field
      submit(:SEND.l, center: true)
    end
  end

  private

  def render_subject_field
    text_field(:subject, label: "#{:ask_user_question_subject.t}:",
                         value: @subject, size: 70,
                         data: { autofocus: true })
  end

  def render_message_field
    textarea_field(:message, label: "#{:ask_user_question_message.t}:",
                             value: @message, rows: 10)
  end

  def form_action
    url_for(action: :create, id: @target.id)
  end
end

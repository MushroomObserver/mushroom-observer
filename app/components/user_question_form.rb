# frozen_string_literal: true

# Form for sending a question to another user.
# Creates its own FormObject internally from the provided kwargs.
class Components::UserQuestionForm < Components::ApplicationForm
  # Accept optional model arg for ModalForm compatibility (ignored - we create
  # our own FormObject). This is Pattern B: form creates FormObject internally.
  def initialize(_model = nil, target:, subject: nil, message: nil, **)
    @target = target

    form_object = FormObject::UserQuestion.new(
      subject: subject,
      message: message
    )
    super(form_object, **)
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
                         size: 70, data: { autofocus: true })
  end

  def render_message_field
    textarea_field(:message, label: "#{:ask_user_question_message.t}:",
                             rows: 10)
  end

  def form_action
    url_for(action: :create, id: @target.id)
  end
end

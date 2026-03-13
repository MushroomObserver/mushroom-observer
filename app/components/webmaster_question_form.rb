# frozen_string_literal: true

# Form for submitting a question to the webmaster.
# Creates its own FormObject internally from the provided kwargs.
class Components::WebmasterQuestionForm < Components::ApplicationForm
  # Accept optional model arg for ModalForm compatibility (ignored - we create
  # our own FormObject). This is Pattern B: form creates FormObject internally.
  def initialize(_model = nil, reply_to: nil, message: nil, email_error: false,
                 **)
    @email_error = email_error

    form_object = FormObject::EmailRequest.new(
      reply_to: reply_to,
      message: message
    )
    super(form_object, **)
  end

  def view_template
    p { :ask_webmaster_note.tp }
    br
    render_email_field
    render_message_field
    submit(:SEND.l, center: true)
  end

  private

  def render_email_field
    autofocus = model.reply_to.blank? || @email_error
    text_field(:reply_to, label: "#{:ask_webmaster_your_email.t}:", size: 60,
                          data: { autofocus: autofocus })
  end

  def render_message_field
    autofocus = model.reply_to.present? && !@email_error
    textarea_field(:message, label: "#{:ask_webmaster_question.t}:", rows: 10,
                             data: { autofocus: autofocus })
  end

  def form_action
    url_for(action: :create)
  end
end

# frozen_string_literal: true

# Form for submitting a question to the webmaster.
# Allows users to ask questions about the site.
class Components::WebmasterQuestionForm < Components::ApplicationForm
  def initialize(model, email_error: false, **)
    @email_error = email_error
    super(model, **)
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
    text_field(:reply_to, label: "#{:ask_webmaster_your_email.t}:", size: 60,
                          data: { autofocus: model.reply_to.blank? || @email_error })
  end

  def render_message_field
    textarea_field(:message, label: "#{:ask_webmaster_question.t}:", rows: 10,
                             data: { autofocus: model.reply_to.present? &&
                                                !@email_error })
  end

  def form_action
    url_for(action: :create)
  end
end

# frozen_string_literal: true

# Form for submitting a question to the webmaster.
# Allows users to ask questions about the site.
class Components::WebmasterQuestionForm < Components::ApplicationForm
  def initialize(model, email: nil, email_error: false, message: nil, **)
    @email = email
    @email_error = email_error
    @message = message
    super(model, **)
  end

  def view_template
    super do
      p { :ask_webmaster_note.tp }
      br
      render_email_field
      render_question_field
      submit(:SEND.l, center: true)
    end
  end

  private

  def render_email_field
    render(field(:email).text(
             wrapper_options: {
               label: "#{:ask_webmaster_your_email.t}:"
             },
             value: @email,
             size: 60,
             data: {
               autofocus: @email.blank? || @email_error
             }
           ))
  end

  def render_question_field
    render(field(:message).textarea(
             wrapper_options: {
               label: "#{:ask_webmaster_question.t}:"
             },
             value: @message,
             rows: 10,
             data: {
               autofocus: @email.present? && !@email_error
             }
           ))
  end

  def form_action
    url_for(action: :create)
  end
end

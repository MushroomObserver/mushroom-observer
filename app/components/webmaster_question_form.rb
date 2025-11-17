# frozen_string_literal: true

# Form for submitting a question to the webmaster.
# Allows users to ask questions about the site.
class Components::WebmasterQuestionForm < Components::ApplicationForm
  prop :email
  prop :email_error, default: false
  prop :content

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
    namespace(:user) do |builder|
      builder.field(:email).text(
        wrapper_options: {
          label: "#{:ask_webmaster_your_email.t}:"
        },
        value: @email,
        size: 60,
        data: {
          autofocus: @email.blank? || @email_error
        }
      )
    end
  end

  def render_question_field
    namespace(:question) do |builder|
      builder.field(:content).textarea(
        wrapper_options: {
          label: "#{:ask_webmaster_question.t}:"
        },
        value: @content,
        rows: 10,
        data: {
          autofocus: @email.present? && !@email_error
        }
      )
    end
  end

  def form_action
    { action: :create }
  end
end

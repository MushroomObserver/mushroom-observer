# frozen_string_literal: true

# Form for asking the observer a question about their observation.
class Components::ObserverQuestionForm < Components::ApplicationForm
  def initialize(model, observation:, message: nil, **)
    @observation = observation
    @message = message
    super(model, **)
  end

  def view_template
    super do
      render_user_label
      render_message_field
      submit(:SEND.l, center: true)
    end
  end

  private

  def render_user_label
    bold_user = "**#{@observation.user.legal_name}**"
    p { :ask_observation_question_label.t(user: bold_user) }
  end

  def render_message_field
    label = "#{:ask_user_question_message.t}:"
    render(field(:message).textarea(
             wrapper_options: { label: label },
             value: @message,
             rows: 6,
             data: { autofocus: true }
           ))
  end

  def form_action
    url_for(action: :create, id: @observation.id)
  end
end

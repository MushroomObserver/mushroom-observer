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
      render_message_field
      submit(:SEND.l, center: true)
    end
  end

  private

  def render_message_field
    label = :ask_observation_question_label.tp(
      user: @observation.user.legal_name
    )
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

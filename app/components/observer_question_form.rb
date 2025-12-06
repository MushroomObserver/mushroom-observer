# frozen_string_literal: true

# Form for submitting a question to the observation owner.
# Allows users to ask questions about an observation.
class Components::ObserverQuestionForm < Components::ApplicationForm
  def initialize(observation:, message: nil, **)
    @observation = observation
    model = FormObject::ObserverQuestion.new(message:)
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
    render(field(:message).textarea(
             wrapper_options: {
               label: :ask_observation_question_label.tp(
                 user: @observation.user.legal_name
               )
             },
             rows: 6,
             data: { autofocus: true }
           ))
  end

  def form_action
    url_for(controller: "observations/emails", action: :create,
            id: @observation.id)
  end
end

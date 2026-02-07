# frozen_string_literal: true

# Form for asking the observer a question about their observation.
# Creates its own FormObject internally from the provided kwargs.
class Components::ObserverQuestionForm < Components::ApplicationForm
  # Accept optional model arg for ModalForm compatibility (ignored - we create
  # our own FormObject). This is Pattern B: form creates FormObject internally.
  def initialize(_model = nil, observation:, message: nil, **)
    @observation = observation

    form_object = FormObject::ObserverQuestion.new(message: message)
    super(form_object, **)
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
    textarea_field(:message, label: "#{:ask_user_question_message.t}:",
                             rows: 6, data: { autofocus: true })
  end

  def form_action
    url_for(action: :create, id: @observation.id)
  end
end

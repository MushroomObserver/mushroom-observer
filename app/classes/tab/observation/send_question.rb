# frozen_string_literal: true

class Tab::Observation::SendQuestion < Tab::Base
  def initialize(observation:)
    super()
    @observation = observation
  end

  def title
    :show_observation_send_question.l
  end

  def path
    new_question_for_observation_path(@observation.id)
  end

  def html_options
    { icon: :email }
  end

  def model
    @observation
  end
end

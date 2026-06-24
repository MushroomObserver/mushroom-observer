# frozen_string_literal: true

# "Propose a new naming on this observation" link. Caller supplies
# the text + rendering context (namings_table, matrix_box, etc.).
# Visual framing (btn classes, icon visibility) is the caller's
# responsibility via `Components::Button::ModalToggle`.
class Tab::Naming::New < Tab::Base
  def initialize(observation_id:, text:, context:)
    super()
    @observation_id = observation_id
    @text = text
    @context = context
  end

  def title
    @text
  end

  def path
    new_observation_naming_path(
      observation_id: @observation_id, context: @context
    )
  end

  def html_options
    { class: "propose-naming-link" }
  end

  def model
    Naming
  end
end

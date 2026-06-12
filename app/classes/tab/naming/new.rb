# frozen_string_literal: true

# "Propose a new naming on this observation" link. Caller supplies
# the text + button class because this tab is rendered from the
# namings_table in several visual contexts (table footer button,
# matrix-box button, etc.) with different framing.
class Tab::Naming::New < Tab::Base
  def initialize(observation_id:, text:, context:, btn_class:)
    super()
    @observation_id = observation_id
    @text = text
    @context = context
    @btn_class = btn_class
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
    {
      class: [@btn_class, "propose-naming-link"].compact.join(" "),
      icon: :add
    }
  end

  def model
    Naming
  end
end

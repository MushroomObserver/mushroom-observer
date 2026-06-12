# frozen_string_literal: true

# Action-nav for the naming new/edit forms — single cancel-to-obs
# link. Replaces `naming_form_new_tabs` / `naming_form_edit_tabs`.
class Tab::Observation::NamingForm < Tab::Collection
  def initialize(observation:)
    super()
    @observation = observation
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @observation)]
  end
end

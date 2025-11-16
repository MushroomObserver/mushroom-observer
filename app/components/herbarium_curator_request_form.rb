# frozen_string_literal: true

# Form for requesting to be a herbarium curator
class Components::HerbariumCuratorRequestForm < Components::ApplicationForm
  def initialize(model, herbarium_name:, **)
    @herbarium_name = herbarium_name
    super(model, **)
  end

  def view_template
    div(class: "form-group mt-3") { "#{:HERBARIUM.l}: #{@herbarium_name}" }

    textarea_field(:notes, label: "#{:NOTES.l}:", rows: 10,
                           data: { autofocus: true })

    submit(:SEND.l, center: true)
  end
end

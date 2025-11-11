# frozen_string_literal: true

# Form for requesting to be a herbarium curator
class Components::HerbariumCuratorRequestForm < Components::ApplicationForm
  def initialize(model, herbarium_name:, **)
    @herbarium_name = herbarium_name
    super(model, **)
  end

  def view_template
    div(class: "form-group mt-3") do
      "#{:HERBARIUM.l}: #{@herbarium_name}"
    end

    textarea_field(:notes, label: "#{:NOTES.l}:", rows: 10,
                           data: { autofocus: true })

    submit(:SEND.l, class: "btn btn-default center-block my-3",
                    data: { turbo_submits_with: :SUBMITTING.l,
                            disable_with: :SEND.l })
  end
end

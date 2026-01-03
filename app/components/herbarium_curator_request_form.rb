# frozen_string_literal: true

# Form for requesting to be a herbarium curator
class Components::HerbariumCuratorRequestForm < Components::ApplicationForm
  register_value_helper :herbaria_curator_requests_path

  def initialize(model, herbarium:, back: nil, q_param: nil, **options)
    @herbarium = herbarium
    @back = back
    @q_param = q_param
    options[:id] ||= "herbarium_curator_request_form"
    super(model, **options)
  end

  def form_action
    herbaria_curator_requests_path(id: @herbarium, back: @back, q: @q_param)
  end

  def view_template
    div(class: "form-group mt-3") do
      strong { "#{:HERBARIUM.l}:" }
      whitespace
      plain(@herbarium.name)
    end

    textarea_field(:notes, label: "#{:NOTES.l}:", rows: 10,
                           data: { autofocus: true })

    submit(:SEND.l, center: true)
  end
end

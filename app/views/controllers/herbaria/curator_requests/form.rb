# frozen_string_literal: true

module Views::Controllers::Herbaria::CuratorRequests
  # Form for requesting to be a herbarium curator. Rendered by the
  # herbaria/curator_requests controller's `new.rb`.
  class Form < ::Components::ApplicationForm
    def initialize(model, herbarium:, back: nil, q_param: nil, **options)
      @herbarium = herbarium
      @back = back
      @q_param = q_param
      options[:id] ||= "herbarium_curator_request_form"
      super(model, **options)
    end

    def form_action
      herbaria_curator_requests_path(id: @herbarium,
                                     back: @back,
                                     q: @q_param)
    end

    def view_template
      div(class: "form-group mt-3") do
        strong { "#{:herbarium.ti}:" }
        whitespace
        plain(@herbarium.name)
      end

      textarea_field(:notes, label: :notes.ti, rows: 10,
                             data: { autofocus: true })

      submit(:send.ti, center: true)
    end
  end
end

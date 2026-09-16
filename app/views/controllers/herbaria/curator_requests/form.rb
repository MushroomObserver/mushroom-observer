# frozen_string_literal: true

module Views::Controllers::Herbaria::CuratorRequests
  # Form for requesting to be a herbarium curator. Rendered by the
  # herbaria/curator_requests controller's `new.rb`.
  class Form < ::Components::ApplicationForm
    prop :herbarium, ::Herbarium
    prop :back, _Nilable(String), default: nil

    def initialize(model, id: nil, **)
      super(model, id: id || "herbarium_curator_request_form", **)
    end

    # `q_param` is the ambient current-query helper (Components::Base
    # registers it), not something specific to this form's caller --
    # calling it directly instead of threading it through as a prop.
    def form_action
      herbaria_curator_requests_path(id: @herbarium,
                                     back: @back,
                                     q: q_param)
    end

    def view_template
      div(class: "form-group mt-3") do
        strong { append_colon(:herbarium.ti) }
        plain(@herbarium.name)
      end

      textarea_field(:notes, label: :notes.ti, rows: 10,
                             data: { autofocus: true })

      submit(:send.ti, center: true)
    end
  end
end

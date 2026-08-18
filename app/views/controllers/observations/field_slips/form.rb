# frozen_string_literal: true

# "Attach to Field Slip" form -- a single code field, PUT back to
# `Observations::FieldSlipsController#update`. Pattern B (creates its
# own FormObject internally, see `.claude/rules/phlex_reference.md`).
module Views::Controllers::Observations::FieldSlips
  class Form < Components::ApplicationForm
    prop :observation, ::Observation

    def initialize(_model = nil, observation:, **attrs)
      super(FormObject::FieldSlipAttach.new, observation: observation,
                                             **attrs)
    end

    def view_template
      super do
        text_field("field_code", label: :field_slip_code)
        submit(:field_slip_attach_submit.t)
      end
    end

    def form_action
      observation_field_slip_path(id: @observation.id)
    end
  end
end

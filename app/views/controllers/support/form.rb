# frozen_string_literal: true

module Views::Controllers::Support
  # Donation form — preset-amount radios + "other" amount + recurring
  # checkbox + name / anonymous / email fields. `data-controller=
  # "collapse-switch"` collapses the "other amount" field except when
  # the "other" radio is selected. `data-controller="donate"` (the
  # whole form) converts the typed "other amount" value and keeps
  # the "other" radio checked while editing it.
  class Form < ::Components::ApplicationForm
    PRESET_AMOUNTS = [25.00, 50.00, 100.00, 200.00].freeze

    def initialize(model, **attrs)
      attrs[:data] = (attrs[:data] || {}).merge(controller: "donate")
      super
    end

    def view_template
      super do
        div(data: { controller: "collapse-switch" }) do
          render_amount_row
          render_other_amount_inputs
        end
        checkbox_field(:recurring, label: :donate_recurring,
                                   wrap_class: "mb-3")
        text_field(:who, size: 30, label: :donate_who, inline: true)
        checkbox_field(:anonymous, label: :donate_anonymous,
                                   wrap_class: "mb-3")
        text_field(:email, size: 30, label: :donate_email, inline: true)
        submit(:donate_confirm.l, center: true)
      end
    end

    private

    def render_amount_row
      Row do
        PRESET_AMOUNTS.each do |amount|
          Column(xs: 3) do
            render(Components::Form::RadioCollapse.new(
                     form: self, field: :amount, value: amount,
                     label: "$#{amount.to_i}"
                   ))
          end
        end
      end
    end

    def render_other_amount_inputs
      render(Components::Form::RadioCollapse.new(
               form: self, field: :amount, value: "other",
               label: append_colon(:donate_other.l),
               attributes: { data: { donate_target: "otherCheck" } }
             ))
      Collapsible(expanded: other_amount_selected?,
                  data: { collapse_switch_target: "panel",
                          collapse_switch_type: "other" }) do
        text_field(:other_amount, size: 6, label: false,
                                  addon: "$", addon_position: :prepend,
                                  wrap_class: "ml-4",
                                  data: { donate_target: "otherAmount",
                                          action: "click->donate#checkOther " \
                                                  "keyup->donate#convert" })
      end
    end

    def other_amount_selected?
      model.amount.to_s == "other"
    end
  end
end

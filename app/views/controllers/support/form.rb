# frozen_string_literal: true

module Views::Controllers::Support
  # Donation form — preset-amount radios + "other" amount + recurring
  # checkbox + name / anonymous / email fields. Stimulus
  # `data-controller="donate"` flips the "other amount" text input
  # active when its radio is selected and converts the typed amount
  # into the form's amount value.
  class Form < ::Components::ApplicationForm
    PRESET_AMOUNTS = [25.00, 50.00, 100.00, 200.00].freeze

    def initialize(model, **)
      super
      @attributes ||= {}
      @attributes[:data] =
        (@attributes[:data] || {}).merge(controller: "donate")
    end

    def view_template
      super do
        render_amount_row
        render_other_amount_inputs
        checkbox_field(:recurring, label: :donate_recurring.l)
        text_field(:who, size: 30, label: :donate_who.l, inline: true)
        checkbox_field(:anonymous, label: :donate_anonymous.l)
        text_field(:email, size: 30, label: :donate_email.l, inline: true)
        submit(:donate_confirm.l, center: true)
      end
    end

    private

    def render_amount_row
      div(class: "row") do
        PRESET_AMOUNTS.each do |amount|
          Column(xs: 3) do
            radio_field(:amount, [amount, "$#{amount.to_i}"])
          end
        end
      end
    end

    def render_other_amount_inputs
      radio_field(:amount, ["other", "#{:donate_other.l}: "],
                  wrap_class: "d-inline-block",
                  data: { donate_target: "otherCheck" })
      text_field(:other_amount, size: 7, label: "$ ", inline: true,
                                wrap_class: "d-inline-block ml-4",
                                data: { donate_target: "otherAmount",
                                        action: "click->donate#checkOther " \
                                                "keyup->donate#convert" })
    end
  end
end

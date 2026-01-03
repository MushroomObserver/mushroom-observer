# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Renders a pair of select fields for range selection (e.g., rank range,
  # confidence range). Both selects share the same options list.
  #
  # @example Usage in a form
  #   render(SelectRangeField.new(
  #     form: f,
  #     field_name: :rank,
  #     options: [nil] + Name.all_ranks,
  #     value: current_rank,
  #     range_value: current_range_rank,
  #     label: "Rank"
  #   )) do |field|
  #     field.with_help { "Select a rank range" }
  #   end
  class SelectRangeField < Components::Base
    include Phlex::Slotable

    prop :form, _Any
    prop :field_name, Symbol
    prop :options, _Array(Object)
    prop :value, _Nilable(_Any), default: nil
    prop :range_value, _Nilable(_Any), default: nil
    prop :label, String

    slot :help

    def view_template
      div do
        div(class: "d-inline-block mr-4") do
          @form.select_field(@field_name, @options,
                             label: @label,
                             inline: true,
                             selected: @value) do |f|
            f.with_help { render(help_slot) } if help_slot
          end
        end
        div(class: "d-inline-block") do
          @form.select_field(:"#{@field_name}_range", @options,
                             label: :to.l,
                             inline: true,
                             selected: @range_value)
        end
      end
    end
  end
end

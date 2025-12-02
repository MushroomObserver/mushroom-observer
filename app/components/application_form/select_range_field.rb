# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Renders a pair of select fields for range selection (e.g., rank range,
  # confidence range). Both selects share the same options list.
  #
  # @example Usage in a form
  #   render_select_range(
  #     field_name: :rank,
  #     options: [nil] + Name.all_ranks,
  #     value: current_rank,
  #     range_value: current_range_rank,
  #     label: "Rank",
  #     help: "Select a rank range"
  #   )
  class SelectRangeField < Components::Base
    prop :form, _Any
    prop :field_name, Symbol
    prop :options, _Array(Object)
    prop :value, _Nilable(_Any), default: nil
    prop :range_value, _Nilable(_Any), default: nil
    prop :label, String
    prop :help, _Nilable(String), default: nil

    def view_template
      div do
        div(class: "d-inline-block mr-4") do
          @form.select_field(@field_name, @options,
                             label: @label,
                             help: @help,
                             inline: true,
                             selected: @value)
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

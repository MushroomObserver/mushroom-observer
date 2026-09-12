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
    include FieldWithHelp

    prop :form, ::Components::ApplicationForm
    prop :field_name, Symbol
    # Rails options-for-select shape: a flat array of values, OR
    # an array of `[label, value]` tuples. Callers mix both — rank
    # passes flat strings ("Form", "Variety", ...), confidence
    # passes `[label, numeric]` tuples — so the element type is a
    # union of those two shapes. The tuple value type mirrors the
    # `value` prop above (String / Integer / Float).
    prop :options,
         _Array(
           _Union(
             _Nilable(String),
             _Tuple(String, _Nilable(_Union(String, Integer, Float)))
           )
         )
    prop :value, _Nilable(_Union(String, Integer, Float)), default: nil
    prop :range_value, _Nilable(_Union(String, Integer, Float)), default: nil
    prop :label, String

    slot :help

    def view_template
      div do
        div(class: "d-inline-block mr-4") do
          @form.select_field(@field_name, @options,
                             label: @label,
                             inline: true,
                             selected: @value,
                             wrap_class: "mb-0")
        end
        div(class: "d-inline-block") do
          @form.select_field(:"#{@field_name}_range", @options,
                             label: :to,
                             label_colon: false,
                             inline: true,
                             selected: @range_value,
                             wrap_class: "mb-0")
        end
      end
      render_help_after_field
    end

    private

    # FieldWithHelp#help_id wants the single field it's attached to --
    # use the first (non-range) select, matching where help rendered
    # before this class threaded its own help_slot into that field
    # directly.
    def field
      @form.field(@field_name)
    end

    # FieldWithHelp#render_help_after_field checks
    # wrapper_options[:help_collapse] -- this class doesn't support
    # collapsible help (no caller has ever needed it), so a plain
    # empty hash always takes the plain-help branch.
    def wrapper_options
      {}
    end
  end
end

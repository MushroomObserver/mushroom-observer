# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap checkbox field component.
  #
  # **Boolean mode** (no positional options): renders the canonical Rails
  # hidden+checkbox pair wrapped in a single `<div class="checkbox"><label>`.
  # Delegates the input rendering to `Superform::Rails::Components::Checkbox`
  # (boolean branch), so we inherit the hidden-field convention and
  # checked-state computation.
  #
  # **Array mode** (options passed): renders a group of checkboxes for a
  # single multi-valued field via `Superform::Rails::Components::Checkboxes`,
  # wrapping each option in its own `<div class="checkbox"><label>`.
  # The caller must back this with a FormObject attribute that's array-typed
  # (returns `[]` not `nil` when empty) so upstream `Checkbox` picks the
  # array branch — otherwise it'll fall back to boolean rendering per option.
  class CheckboxField < Superform::Rails::Components::Checkbox
    include Phlex::Slotable
    include FieldWithHelp
    include Components::TrustedHtml

    slot :between
    slot :append
    slot :help

    public :between_slot, :append_slot, :help_slot

    attr_reader :wrapper_options

    def initialize(field, *options, wrapper_options: {}, **attributes)
      @options = options
      @wrapper_options = wrapper_options
      # Upstream 0.7 Checkbox#initialize is (field, index: nil, **attributes).
      super(field, **attributes)
    end

    def view_template(&block)
      if @options.any?
        render_array_mode
      elsif block
        # Block mode: caller drives rendering via `cb.option(value)` for
        # one or more checkboxes inside MO's standard wrapper. Used for
        # matrix-style layouts where one checkbox_field call produces
        # exactly one cell of a larger group.
        render_boolean_with_wrapper { yield(self) }
      else
        render_boolean_with_wrapper { super }
      end
    end

    # Render a single array-mode checkbox (name="…[]"). Intended for use
    # inside a block passed to `checkbox_field`, when the caller wants
    # one cell of a larger checkbox matrix.
    def option(value)
      input(
        type: :checkbox,
        id: "#{field.dom.id}_#{value}",
        name: "#{field.dom.name}[]",
        value: value.to_s,
        checked: checked_in_array?(value),
        **@attributes.except(:id, :name, :value, :type, :checked)
      )
      return unless block_given?

      trusted_html(yield)
    end

    private

    # --- Array mode ---

    def render_array_mode
      render(checkboxes_component) do |choice|
        render_checkbox_option(choice)
      end
    end

    def checkboxes_component
      Superform::Rails::Components::Checkboxes.new(
        field, options: @options, **@attributes
      )
    end

    def render_checkbox_option(choice)
      div(class: option_wrap_class) do
        label do
          render(choice.build_input(**@attributes))
          whitespace
          trusted_html(choice.text)
        end
      end
    end

    def checked_in_array?(value)
      field_value = field.value
      return false if field_value.nil?

      field_value = [field_value] unless field_value.is_a?(Array)
      field_value.map(&:to_s).include?(value.to_s)
    end

    # --- Boolean mode wrapper ---

    def render_boolean_with_wrapper(&checkbox_block)
      div(class: boolean_wrap_class) do
        label(for: checkbox_id, **label_attributes) do
          render_boolean_content(&checkbox_block)
          render_help_in_label_row
        end
        render_help_after_field
        render(append_slot) if append_slot
      end
    end

    # MO's default render order is checkbox-then-label
    def render_boolean_content
      text = label_text
      if label_position_before?
        if text
          trusted_html(text)
          whitespace
        end
        render_between_slot
        yield
      else
        yield
        render_between_slot
        if text
          whitespace
          trusted_html(text)
        end
      end
    end

    # Use custom ID if provided, otherwise use Superform's generated ID
    def checkbox_id
      @attributes[:id] || field.dom.id
    end

    def label_position_before?
      wrapper_options[:label_position] == :before
    end

    def label_text
      label_option = wrapper_options[:label]
      return if label_option == false

      label_option.is_a?(String) ? label_option : field.key.to_s.humanize
    end

    def boolean_wrap_class
      classes = "checkbox"
      classes += " #{wrapper_options[:wrap_class]}" if wrap_class?
      classes
    end

    # Each per-option label gets its own .checkbox wrapper too
    alias option_wrap_class boolean_wrap_class

    def wrap_class?
      wrapper_options[:wrap_class].present?
    end

    def label_attributes
      attrs = {}
      [:label_class, :label_data, :label_aria].each do |opt|
        next unless wrapper_options[opt]

        attrs[opt.to_s.sub("label_", "").to_sym] = wrapper_options[opt]
      end
      attrs
    end
  end
end

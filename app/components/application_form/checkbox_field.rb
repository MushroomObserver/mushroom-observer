# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap 4 custom-checkbox field component.
  #
  # Every rendered checkbox -- boolean, array, or block mode -- is a
  # `<div class="custom-control custom-checkbox">` wrapping an
  # `<input class="custom-control-input">` and a sibling
  # `<label class="custom-control-label">`. Sibling order (input, then
  # label) is load-bearing: the indicator graphic is painted via
  # `.custom-control-input ~ .custom-control-label` CSS, which only
  # matches sibling elements, not nested ones.
  #
  # **Boolean mode** (no positional options, no block): renders Rails'
  # hidden+checkbox pair. Delegates to
  # `Superform::Rails::Components::Checkbox` (boolean branch) for the
  # hidden-field convention and checked-state computation.
  #
  # **Array mode** (options passed): renders a group of checkboxes for
  # a single multi-valued field via
  # `Superform::Rails::Components::Checkboxes`. The caller must back
  # this with a FormObject attribute that's array-typed (returns `[]`
  # not `nil` when empty) so upstream `Checkbox` picks the array
  # branch -- otherwise it'll fall back to boolean rendering per option.
  #
  # **Block mode** (a block, no options): caller drives rendering via
  # `cb.option(value) { ... }` for one or more checkboxes inside one
  # `checkbox_field` call -- matrix-style layouts where each call
  # produces one cell of a larger group.
  class CheckboxField < Superform::Rails::Components::Checkbox
    include Phlex::Slotable
    include FieldWithHelp
    include FieldLabelRow

    slot :between
    slot :append
    slot :help

    public :between_slot, :append_slot, :help_slot

    attr_reader :wrapper_options

    def initialize(field, *options, wrapper_options: {}, **attributes)
      # MO convention: array-mode options arrive as Rails-shape
      # `[label, value]` pairs (matching `select_field` and
      # `radio_field`'s positional-choices shape). Flip to
      # Superform-shape `[value, label]` for the underlying
      # `Choices::Mapper` to unpack correctly. Non-pair options
      # (bare values, hashes) pass through unchanged — Mapper handles
      # them itself.
      @options = options.map do |opt|
        opt.is_a?(Array) && opt.size == 2 ? [opt[1], opt[0]] : opt
      end
      @wrapper_options = wrapper_options
      # Upstream 0.7 Checkbox#initialize is (field, index: nil, **attributes).
      super(field, **attributes)
    end

    def view_template(&block)
      if @options.any?
        render_array_mode
      elsif block
        div(class: wrap_class) do
          yield(self)
          render_between_slot
          render_help_in_label_row
          render_help_after_field
          render(append_slot) if append_slot
        end
      else
        render_boolean_mode
      end
    end

    # Replaces upstream Checkbox's boolean rendering so the hidden
    # sidecar gets `autocomplete="off"` -- without it, browsers
    # repopulate the hidden "0" on back-button and clobber a checked
    # box. `checked_value:`/`unchecked_value:` mirror Rails' positional
    # args; `disabled: true` omits the sidecar since it wouldn't submit.
    def render_boolean_inputs
      unless disabled?
        input(name: field.dom.name, type: :hidden,
              value: unchecked_value, autocomplete: "off")
      end
      input(type: :checkbox, value: checked_value, **checkbox_attributes)
    end

    def checked_value
      @attributes[:checked_value] || "1"
    end

    def unchecked_value
      @attributes[:unchecked_value] || "0"
    end

    # Strip the custom-value kwargs before splatting into `<input>`
    # (`checked_value`/`unchecked_value` aren't valid HTML attributes).
    # When the caller passes a custom `checked_value`, recompute
    # `checked` via string comparison (Superform's default
    # `field_attributes` uses `field.value` directly, which is correct
    # for the boolean "1"/"0" case but wrong for "yes"/"no" etc.).
    def checkbox_attributes
      attrs = attributes.except(:checked_value, :unchecked_value)
      if @attributes.key?(:checked_value)
        attrs[:checked] = field.value.to_s == checked_value.to_s
      end
      attrs[:class] = class_names("custom-control-input", attrs[:class])
      attrs
    end

    def disabled?
      @attributes[:disabled] == true
    end

    # Render a single block-mode checkbox (name="…[]"), input and a
    # sibling label -- one cell of a larger checkbox matrix built via
    # a block passed to `checkbox_field`. `**overrides` lets the
    # caller override any input attribute per option -- most commonly
    # `checked:` (external checkedness state not matching
    # `model.<assoc>_ids`) and `disabled:` (per-row permission gates).
    def option(value, **overrides)
      input_id = "#{field.dom.id}_#{value}"
      input(
        type: :checkbox,
        id: input_id,
        name: "#{field.dom.name}[]",
        value: value.to_s,
        checked: checked_in_array?(value),
        **@attributes.except(:id, :name, :value, :type, :checked, :class),
        class: class_names("custom-control-input", @attributes[:class]),
        **overrides
      )
      label(class: "custom-control-label", for: input_id) do
        trusted_html(yield) if block_given?
      end
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

    # Emits the array-mode input directly instead of delegating to
    # upstream's Checkbox: upstream picks its boolean branch when
    # `field.parent` isn't a `Superform::Field` (true here, parent is
    # the form root), rendering duplicate bare `dom.id`s and a hidden
    # 0/1 pair per option -- wrong for an array submission.
    def render_checkbox_option(choice)
      value_str = choice.value.to_s
      input_id = option_input_id(value_str)
      div(class: wrap_class) do
        input(**option_input_attributes(choice, value_str, input_id))
        label(class: "custom-control-label", for: input_id) do
          trusted_html(choice.text)
        end
      end
    end

    def option_input_attributes(choice, value_str, input_id)
      {
        type: :checkbox,
        id: input_id,
        name: "#{field.dom.name}[]",
        value: value_str,
        checked: checked_in_array?(choice.value),
        **@attributes.except(:id, :name, :value, :type, :checked, :class),
        class: class_names("custom-control-input", @attributes[:class])
      }
    end

    def option_input_id(value_str)
      "#{field.dom.id}_#{index_for(value_str)}"
    end

    def index_for(value_str)
      value_str.parameterize(separator: "_")
    end

    def checked_in_array?(value)
      field_value = field.value
      return false if field_value.nil?

      field_value = [field_value] unless field_value.is_a?(Array)
      field_value.map(&:to_s).include?(value.to_s)
    end

    # --- Boolean mode ---

    # `label_for` can be nil when the caller's id isn't guaranteed
    # unique on the page (e.g. content that gets cloned elsewhere in
    # the DOM, like lightGallery's caption snapshot) -- the label then
    # omits `for=`, and the caller wires click-to-toggle some other
    # way (e.g. a Stimulus action via `label_data:` targeting the
    # input directly, rather than id-based `for=` association).
    def render_boolean_mode
      div(class: wrap_class) do
        render_boolean_inputs
        label(**boolean_label_attributes) do
          text = label_text
          trusted_html(text) if text
          render_between_slot
        end
        render_help_in_label_row
        render_help_after_field
        render(append_slot) if append_slot
      end
    end

    def boolean_label_attributes
      attrs = label_attributes
      attrs[:class] = class_names("custom-control-label", attrs[:class])
      attrs[:for] = boolean_label_for if boolean_label_for
      attrs
    end

    # Use custom ID if provided, otherwise use Superform's generated ID
    def checkbox_id
      @attributes[:id] || field.dom.id
    end

    # Defaults to an explicit `for="<checkbox_id>"` -- a caller can
    # pass `label_for: nil` to omit it (see `render_boolean_mode`).
    def boolean_label_for
      wrapper_options.fetch(:label_for) { checkbox_id }
    end

    # Checkbox labels read as a clickable sentence next to the checkbox
    # itself, not a field prompt -- doesn't get FieldLabelRow's colon.
    def label_text
      return if wrapper_options[:label] == false

      resolved_label_text
    end

    def wrap_class
      base = "custom-control custom-checkbox"
      wrap_class? ? "#{base} #{wrapper_options[:wrap_class]}" : base
    end

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

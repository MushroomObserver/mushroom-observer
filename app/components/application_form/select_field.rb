# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap select field component with form-group wrapper and slots
  class SelectField < Superform::Rails::Components::Select
    include Phlex::Slotable
    include FieldWithHelp
    include FieldLabelRow
    include InputGroupAddon

    slot :between
    slot :append
    slot :help

    public :between_slot, :append_slot, :help_slot

    attr_reader :wrapper_options

    def initialize(field, collection:, wrapper_options: {}, **attributes)
      # Upstream Superform 0.7 renamed `collection:` to `options:` and
      # deprecated passing `attributes:` as a keyword. Spread instead.
      super(field, options: collection, **attributes)
      @wrapper_options = wrapper_options
    end

    def view_template(&options_block)
      # `label: false` skips the form-group wrapper (bare select),
      # matching TextField's behavior.
      if wrapper_options[:label] == false
        render_select(&options_block)
      else
        render_with_wrapper { render_select(&options_block) }
      end
    end

    # Renders the options.
    #
    # IMPORTANT: This wrapper accepts Rails-helper-shape `[label, value]`
    # pairs (e.g. `[["Member", "member"], ["Admin", "admin"]]`), NOT
    # Superform's native `[value, label]` shape. Callers can hand
    # this method the same arrays they'd pass to Rails'
    # `select_tag` / `options_for_select` — no swap needed.
    #
    # The pair is flipped internally so we still produce
    # `<option value="value">label</option>` markup. (Superform
    # 0.7's `Choices::Mapper` yields generic `[a, b]` pairs; we
    # interpret those as `[label, value]` here.)
    #
    # Also overrides Superform's `options(*collection)` to use the
    # wrapper's `selected:` attribute when `field.value` is nil or an
    # array (arrays occur with range fields, e.g.
    # `confidence: [-3.0, -1.0]`). Compares as strings to handle
    # boolean values (Phlex omits `value="false"`).
    def options(*collection)
      map_options(collection).each do |label, value|
        # Coerce nil → "" so `<option value="">` renders (not
        # `<option>`). Phlex's HTML DSL omits nil-valued attributes;
        # the browser would then submit the option's text content.
        # Matches Rails select-helper behavior so callers passing
        # `["Label", nil]` get the expected empty-string submission.
        option_value = value.nil? ? "" : value
        option(selected: option_selected?(value),
               value: option_value) { label }
      end
    end

    def option_selected?(value)
      val = use_selected_attribute? ? attributes[:selected] : field.value
      val.to_s == value.to_s
    end

    def use_selected_attribute?
      field.value.nil? || field.value.is_a?(Array)
    end

    private

    def render_select(&options_block)
      # Exclude `selected` from select tag attrs - it's used by options()
      select_attrs = attributes.except(:selected)
      if options_block
        select(**select_attrs, class: select_classes, &options_block)
      else
        select(**select_attrs, class: select_classes) do
          # Upstream Superform 0.7 stores options on `@options` (was
          # `@collection` in the fork).
          options(*@options)
        end
      end
    end

    def select_classes
      # `width: :auto` adds Bootstrap's `w-auto` so the select shrinks
      # to its content width instead of filling the form-group.
      # Matches ERB `select_with_label`'s `width: :auto` branch.
      base = ["form-control"]
      base << "w-auto" if wrapper_options[:width] == :auto
      class_names(attributes[:class], *base)
    end

    def render_with_wrapper(&block)
      inline = wrapper_options[:inline] || false
      div(class: form_group_class("form-group", inline,
                                  wrapper_options[:wrap_class])) do
        render_label_row(label_text, inline)
        render_select_field(&block)
        render_help_after_field
        render(append_slot) if append_slot
      end
    end

    def render_select_field(&block)
      if wrapper_options[:button]
        render_input_group_button(&block)
      elsif wrapper_options[:addon]
        render_input_group_addon(&block)
      else
        yield
      end
    end

    def label_text
      label_option = wrapper_options[:label]
      label_option.is_a?(String) ? label_option : field.key.to_s.humanize
    end

    def form_group_class(base, inline, wrap_class)
      classes = base
      classes += " form-inline" if inline && base == "form-group"
      classes += " #{wrap_class}" if wrap_class.present?
      classes
    end
  end
end

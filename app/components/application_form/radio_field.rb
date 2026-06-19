# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Bootstrap radio button group component.
  #
  # Each option renders as:
  #   <div class="radio">
  #     <label><input type="radio" ...> label text</label>
  #   </div>
  #
  # Delegates per-option markup generation to
  # `Superform::Rails::Components::Radios`, using its block form so we can
  # wrap each option in the Bootstrap `.radio` div and emit HTML-safe label
  # text via `trusted_html`. The component works equally with a Superform
  # field or a `FieldProxy` (standalone use outside a form).
  #
  # @example Superform field
  #   field(:target).radio(
  #     [1, "Option 1"], [2, "Option 2"],
  #     wrapper_options: { wrap_class: "mt-3" }
  #   )
  #
  # @example Standalone with FieldProxy
  #   proxy = FieldProxy.new("chosen_name", :name_id)
  #   RadioField.new(proxy, [1, "Opt 1"], [2, "Opt 2"])
  #
  # @example Per-choice options (third element of the tuple):
  #   RadioField.new(field,
  #     [1, "Existing"],
  #     [2, "Placeholder", { disabled: true,
  #                          append: -> { a(href: …) { "Create" } } }],
  #     [3, nil, { label_block: -> {
  #       strong { "Bold label" }
  #       div(class: "ml-4 text-muted") { "Help text below" }
  #     }}]
  #   )
  #   # → `disabled` adds the attr to the input; `append` runs as
  #   #   `trusted_html` after the `<label>` (sibling — keeps links
  #   #   out of the label so a stray click doesn't activate the radio);
  #   #   `label_block` is invoked inside `<label>` via instance_exec in
  #   #   RadioField's Phlex context, replacing the text label for that
  #   #   one option (compound multi-element labels without string-building).
  class RadioField < Phlex::HTML
    include Phlex::Slotable
    include Phlex::TrustedHtml

    slot :between
    slot :append

    public :between_slot, :append_slot

    attr_reader :wrapper_options, :field, :attributes

    def initialize(field, *collection, wrapper_options: {}, **attributes)
      super()
      @field = field
      @collection, @per_choice_opts = split_per_choice_opts(collection)
      @attributes = attributes
      @wrapper_options = wrapper_options
    end

    def view_template
      render(radios_component) do |choice|
        render_choice(choice)
      end
      # `append_slot` content is emitted once, *after* the entire radio
      # group. Differs from ERB `radio_with_label`'s per-option `append:`
      # because the Phlex helper is per-group (one call renders every
      # option) — append-after-each isn't a coherent concept here.
      render(append_slot) if append_slot
    end

    private

    def radios_component
      Superform::Rails::Components::Radios.new(
        @field, options: @collection, **@attributes
      )
    end

    def render_choice(choice)
      value_str = choice.value.to_s
      opts = @per_choice_opts[value_str] || {}
      div(class: radio_class) do
        label(for: option_input_id(value_str)) do
          render_choice_radio(value_str, opts)
          whitespace
          render_choice_label(choice, opts)
          render_between_slot
        end
        render_choice_append(opts)
      end
    end

    # `append` is a sibling of `<label>` inside `.radio` — keeps
    # links/buttons out of the label so a stray click doesn't
    # activate the radio. Accepts either a `Proc`/lambda (invoked in
    # RadioField's Phlex render context — full DSL) or an html_safe
    # `SafeBuffer` (emitted via `trusted_html`).
    def render_choice_append(opts)
      append = opts[:append]
      return unless append

      if append.respond_to?(:call)
        instance_exec(&append)
      else
        trusted_html(append)
      end
    end

    def render_choice_radio(value_str, opts)
      # Stringify value so Phlex doesn't dasherize symbols
      # (e.g. `:mycoportal_image_list` → `"mycoportal-image-list"`).
      # Use a value-derived index so the rendered id is value-based
      # (`field_id_<value>`), matching MO's pre-upstream convention
      # used by JS/CSS, rather than upstream's default index-based id.
      # `checked` is computed here because upstream Radio's
      # `field.value == @value` doesn't coerce types — MO routinely
      # pairs boolean/symbol field values with string option values.
      render(Superform::Rails::Components::Radio.new(
               @field,
               value: value_str,
               index: index_for(value_str),
               checked: option_checked?(value_str),
               disabled: opts[:disabled],
               **@attributes
             ))
    end

    # `label_block:` takes precedence over `choice.text` and runs in
    # RadioField's Phlex render context — gives callers the full Phlex
    # DSL for compound labels (e.g. `strong { ... } div { ... }`)
    # without forcing them to pre-build an html_safe string.
    def render_choice_label(choice, opts)
      if opts[:label_block]
        instance_exec(&opts[:label_block])
      else
        trusted_html(choice.text)
      end
    end

    # Accept either `[value, label]` (the original two-tuple) or
    # `[value, label, opts]` (extended) per choice. Strip the opts so
    # Superform's `Radios` iteration sees the plain two-tuples it
    # expects; remember opts indexed by stringified value for
    # `render_choice` to look up.
    def split_per_choice_opts(collection)
      pairs = []
      opts_by_value = {}
      collection.each do |entry|
        value, label, opts = entry
        pairs << [value, label]
        opts_by_value[value.to_s] = opts if opts
      end
      [pairs, opts_by_value]
    end

    # `between` content is rendered after the label text inside each
    # option's `<label>`, wrapped in `<div class="d-inline-block ml-3">`
    # — matching ERB `radio_with_label`'s `between:` shape. Applied
    # uniformly to every option (one slot per RadioField call). For
    # per-option metadata, supply different content per call site.
    def render_between_slot
      return unless between_slot

      div(class: "d-inline-block ml-3") { render(between_slot) }
    end

    def index_for(value_str)
      value_str.parameterize(separator: "_")
    end

    def option_input_id(value_str)
      "#{@field.dom.id}_#{index_for(value_str)}"
    end

    def option_checked?(value_str)
      @field.value.to_s == value_str
    end

    def radio_class
      classes = "radio"
      if wrapper_options[:wrap_class].present?
        classes += " #{wrapper_options[:wrap_class]}"
      end
      classes
    end
  end
end

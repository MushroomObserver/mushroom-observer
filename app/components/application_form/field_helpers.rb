# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Mixin providing all Bootstrap-styled field helper methods.
  # Included by Components::ApplicationForm; requires the including class
  # to provide Superform's +field+ and +render+ methods.
  #
  # Consult this file (alongside +application_form.rb+) to see the full
  # set of field helpers available in form components.
  module FieldHelpers
    include Components::ButtonStyling

    # Wrapper option keys that should not be passed to the field itself
    WRAPPER_OPTIONS = [:label, :help, :prefs, :inline, :wrap_class,
                       :wrap_data, :between, :button, :button_data,
                       :button_text, :button_href, :button_class,
                       :button_target, :button_rel, :button_title,
                       :button_icon, :addon, :monospace, :label_class,
                       :label_data, :label_aria, :label_position,
                       :width, :label_sr_only].freeze

    # Text field with label and Bootstrap form-group wrapper
    # @param field_name [Symbol] the field name
    # @param options [Hash] all field and wrapper options
    # @option options [String,false] :label label text (optional, inferred
    #   from field name), or false to omit label
    # @option options [Boolean] :prefs auto-generate label from prefs
    #   translation
    # @option options [Boolean] :inline render label and field inline
    # @option options [String] :wrap_class CSS classes for wrapper div
    # @option options [String] :class CSS classes for input element
    # @option options [String] :button button text (input-group with btn)
    # @option options [Hash] :button_data data attributes for button
    # All other options passed to the input element
    # @yield [field_component] Optional block to set slots:
    #   `with_between`, `with_append` (after input, end of form-group),
    #   `with_help`
    def text_field(field_name, **options)
      options = auto_label_for_prefs(field_name, options)
      wrapper_opts = options.slice(*WRAPPER_OPTIONS)
      field_opts = options.except(*WRAPPER_OPTIONS)

      f = resolve_field(field_name, value: field_opts[:value])
      field_component = f.text(
        wrapper_options: wrapper_opts,
        **field_opts
      )

      set_help_slot(field_component, wrapper_opts[:help])
      yield(field_component) if block_given?

      render(field_component)
    end

    # Textarea field with label and Bootstrap form-group wrapper
    # @param field_name [Symbol] the field name
    # @param options [Hash] all field and wrapper options
    # @option options [Boolean] :monospace add monospace font class
    # All other wrapper options same as text_field
    # @yield [field_component] Optional block to set slots:
    #   `with_between`, `with_append`, `with_help`
    def textarea_field(field_name, **options)
      options = auto_label_for_prefs(field_name, options)
      wrapper_opts = options.slice(*WRAPPER_OPTIONS)
      field_opts = options.except(*WRAPPER_OPTIONS)

      # `monospace:` is handled by TextareaField itself via wrapper_options.

      f = resolve_field(field_name, value: field_opts[:value])
      field_component = f.textarea(
        wrapper_options: wrapper_opts,
        **field_opts
      )

      set_help_slot(field_component, wrapper_opts[:help])
      yield(field_component) if block_given?

      render(field_component)
    end

    # Checkbox field with label and Bootstrap checkbox wrapper.
    #
    # Three call styles:
    # - Boolean: `checkbox_field(:public, label: "Public")` — one
    #   checkbox bound to a single field on the model.
    # - Array (multi-value collection):
    #   `checkbox_field(:tag_ids, ["Foo", 1], ["Bar", 2])` —
    #   renders N checkboxes that post as `model[tag_ids][]=<value>`
    #   for each checked option. Pairs are `[label, value]`,
    #   matching `select_field` and `radio_field`.
    # - Block (matrix layout):
    #   `checkbox_field(:foo) { |cb| cb.option(value) }` — caller
    #   drives per-cell rendering inside the standard wrapper.
    #
    # @param field_name [Symbol] the field name
    # @param choices [Array<Array>] optional `[label, value]` pairs
    #   that switch the component into array (collection) mode.
    # @param options [Hash] all field and wrapper options
    # Wrapper options: :label, :prefs, :class_name
    # @yield [field_component] Optional block — see `Field#checkbox`.
    def checkbox_field(field_name, *choices, **options, &block)
      options = auto_label_for_prefs(field_name, options)
      wrapper_opts = options.slice(*WRAPPER_OPTIONS)
      field_opts = options.except(*WRAPPER_OPTIONS)

      # In collection/block mode (`*choices` or `&block`), `value:` is
      # the array-of-checked-ids that drives `checked` state, NOT a
      # value attribute on every input — strip it. In boolean mode it
      # IS the checkbox's submitted value when checked, so leave it.
      collection_mode = choices.any? || block
      f = resolve_field(field_name, value: field_opts[:value])
      field_component = f.checkbox(
        *choices,
        wrapper_options: wrapper_opts,
        **(collection_mode ? field_opts.except(:value) : field_opts)
      )

      set_help_slot(field_component, wrapper_opts[:help])

      render(field_component, &block)
    end

    # Radio button group with Bootstrap radio wrapper per option
    # @param field_name [Symbol] the field name
    # @param choices [Array<Array>] list of [value, label] pairs
    # @param options [Hash] wrapper + HTML options (wrap_class, etc.)
    # @example
    #   radio_field(:target, [1, "Option 1"], [2, "Option 2"])
    def radio_field(field_name, *choices, **options)
      options = auto_label_for_prefs(field_name, options)
      wrapper_opts = options.slice(*WRAPPER_OPTIONS)
      field_opts = options.except(*WRAPPER_OPTIONS)

      # `value:` (String-form path) only carries the selected option for
      # `option_checked?`; strip it from the attributes the field
      # forwards onto each `<input type="radio">` (where `value=` is
      # the per-option value, not the field's currently-selected value).
      f = resolve_field(field_name, value: field_opts[:value])
      field_component = f.radio(
        *choices,
        wrapper_options: wrapper_opts,
        **field_opts.except(:value)
      )

      yield(field_component) if block_given?

      render(field_component)
    end

    # Select field with label and Bootstrap form-group wrapper
    # @param field_name [Symbol] the field name
    # @param options_list [Array] the select options
    # @param options [Hash] all field and wrapper options
    # All wrapper options same as text_field
    # @yield [field_component] Optional block to set slots:
    #   `with_between`, `with_append`, `with_help`
    def select_field(field_name, options_list, **options)
      options = auto_label_for_prefs(field_name, options)
      wrapper_opts = options.slice(*WRAPPER_OPTIONS)
      field_opts = options.except(*WRAPPER_OPTIONS)

      # `value:` only carries the selected option in the String-form
      # path; `<select>` itself takes no `value=` attribute, so drop
      # it from the attributes forwarded to the element.
      f = resolve_field(field_name, value: field_opts[:value])
      field_component = f.select(
        options_list,
        wrapper_options: wrapper_opts,
        **field_opts.except(:value)
      )

      yield(field_component) if block_given?

      render(field_component)
    end

    # Date field with three selects (year, month, day)
    # @param field_name [Symbol] the field name
    # @param options [Hash] all field and wrapper options
    # @option options [Integer] :start_year first year in dropdown
    # @option options [Integer] :end_year last year in dropdown
    # All wrapper options same as text_field
    # @yield [field_component] Optional block to set slots
    def date_field(field_name, **options)
      wrapper_opts = options.slice(*WRAPPER_OPTIONS)
      field_opts = options.except(*WRAPPER_OPTIONS)

      f = resolve_field(field_name, value: field_opts[:value])
      field_component = f.date(
        wrapper_options: wrapper_opts,
        **field_opts
      )

      set_help_slot(field_component, wrapper_opts[:help])
      yield(field_component) if block_given?

      render(field_component)
    end

    # Password field with label and Bootstrap form-group wrapper
    # @param field_name [Symbol] the field name
    # @param options [Hash] all field and wrapper options
    # All wrapper options same as text_field
    # @yield [field_component] Optional block to set slots:
    #   `with_between`, `with_append`, `with_help`
    def password_field(field_name, **options)
      wrapper_opts = options.slice(*WRAPPER_OPTIONS)
      field_opts = options.except(*WRAPPER_OPTIONS)

      # Match ERB `password_field_with_label`: default the input value
      # to "" (prevents Rails from filling the field with the model's
      # stored password hash when the form re-renders after a
      # validation error).
      field_opts[:value] = "" unless field_opts.key?(:value)

      f = resolve_field(field_name, value: field_opts[:value])
      field_component = f.text(
        wrapper_options: wrapper_opts,
        type: "password",
        **field_opts
      )

      yield(field_component) if block_given?

      render(field_component)
    end

    # Hidden field. Two modes based on the type of the first argument:
    #
    # **Symbol** (the common case) — the field is a model / FormObject
    # attribute. The HTML `name` is auto-namespaced under the form's
    # model (e.g. `name="occurrence[observation_id]"`):
    #
    #     hidden_field(:project_id)
    #     hidden_field(:project_id, value: 42)
    #
    # **String** — the caller controls the full HTML `name` attribute.
    # Use this for form-context params that aren't on the model
    # (e.g. a flat redirect-back id) and for Rails' has_many array
    # notation (`field[]`):
    #
    #     hidden_field("observation_id", value: @source_obs.id)
    #     hidden_field("occurrence[observation_ids][]", value: obs.id)
    #     hidden_field("occurrence[observation_ids][]", value: "")
    #
    # The string mode uses `FieldProxy` internally; the symbol mode
    # routes through Superform's `field(...)` for `value`-from-model
    # resolution. Mix freely on the same form.
    #
    # @param field_name [Symbol, String] model attribute name (Symbol)
    #   or full raw HTML `name` (String)
    # @param options [Hash] HTML attributes (`value:`, `data:`, etc.)
    def hidden_field(field_name, **options)
      # Default `autocomplete="off"` to match Rails' `hidden_field` /
      # `hidden_field_tag` (browsers otherwise repopulate hidden fields
      # on back-button). Caller can override with `autocomplete:`.
      options = { autocomplete: "off" }.merge(options)
      f = resolve_field(field_name, value: options[:value])
      render(HiddenField.new(f, **options))
    end

    # Number field with label and Bootstrap form-group wrapper
    # @param field_name [Symbol] the field name
    # @param options [Hash] all field and wrapper options
    # All wrapper options same as text_field
    # @yield [field_component] Optional block to set slots:
    #   `with_between`, `with_append`, `with_help`
    def number_field(field_name, **options)
      options = auto_label_for_prefs(field_name, options)
      wrapper_opts = options.slice(*WRAPPER_OPTIONS)
      field_opts = options.except(*WRAPPER_OPTIONS)

      # Match ERB `number_field_with_label`: default `min: 1`. Callers
      # who want a different minimum pass `min: <n>` explicitly; `min:
      # nil` opts out.
      field_opts[:min] = 1 unless field_opts.key?(:min)

      f = resolve_field(field_name, value: field_opts[:value])
      field_component = f.text(
        wrapper_options: wrapper_opts,
        type: "number",
        **field_opts
      )

      yield(field_component) if block_given?

      render(field_component)
    end

    # Static field - displays a value as plain text (not editable)
    # @param field_name [Symbol] the field name
    # @param options [Hash] all field and wrapper options
    # @option options [String] :value the text to display
    # All wrapper options same as text_field
    # @yield [field_component] Optional block to set slots
    def static_field(field_name, **options)
      # For static fields, :value is a wrapper option (displayed text)
      static_wrapper_opts = WRAPPER_OPTIONS + [:value]
      wrapper_opts = options.slice(*static_wrapper_opts)
      field_opts = options.except(*static_wrapper_opts)

      f = resolve_field(field_name, value: wrapper_opts[:value])
      field_component = f.static(
        wrapper_options: wrapper_opts,
        **field_opts
      )

      yield(field_component) if block_given?

      render(field_component)
    end

    # Read-only field - displays value with hidden input for form submission
    # @param field_name [Symbol] the field name
    # @param options [Hash] all field and wrapper options
    # @option options [String] :value the text to display (also submitted)
    # All wrapper options same as text_field
    # @yield [field_component] Optional block to set slots
    def read_only_field(field_name, **options)
      # For read_only fields, :value is a wrapper option (displayed text)
      read_only_wrapper_opts = WRAPPER_OPTIONS + [:value, :text]
      wrapper_opts = options.slice(*read_only_wrapper_opts)
      field_opts = options.except(*read_only_wrapper_opts)

      f = resolve_field(field_name, value: wrapper_opts[:value])
      field_component = f.read_only(
        wrapper_options: wrapper_opts,
        **field_opts
      )

      yield(field_component) if block_given?

      render(field_component)
    end

    # File field with label and Bootstrap form-group wrapper
    # @param field_name [Symbol] the field name
    # @param options [Hash] all field and wrapper options
    # @option options [String] :accept file type filter (default: "image/*")
    # @option options [Boolean] :multiple allow multiple file selection
    # @option options [String] :controller custom Stimulus controller
    # @option options [String] :action custom Stimulus action
    # @option options [String] :button_text custom button text
    # All wrapper options same as text_field
    # @yield [field_component] Optional block to set slots:
    #   `with_between`, `with_append`
    def file_field(field_name, **options)
      wrapper_opts = options.slice(*WRAPPER_OPTIONS)
      field_opts = options.except(*WRAPPER_OPTIONS)

      f = resolve_field(field_name, value: field_opts[:value])
      field_component = f.file(
        wrapper_options: wrapper_opts,
        **field_opts
      )

      yield(field_component) if block_given?

      render(field_component)
    end

    # Autocompleter field with label and Bootstrap form-group wrapper
    # @param field_name [Symbol] the field name
    # @param type [Symbol] the autocompleter type (:name, :location, etc.)
    # @param options [Hash] all field and wrapper options
    # @option options [Boolean] :textarea use textarea instead of text input
    # All wrapper options same as text_field
    # @yield [field_component] Optional block to set slots:
    #   `with_between`, `with_append`, `with_help`
    def autocompleter_field(field_name, type:, textarea: false, **options)
      wrapper_opts = options.slice(*WRAPPER_OPTIONS)
      field_opts = options.except(*WRAPPER_OPTIONS)

      f = resolve_field(field_name, value: field_opts[:value])
      field_component = f.autocompleter(
        type: type,
        textarea: textarea,
        wrapper_options: wrapper_opts,
        **field_opts
      )

      yield(field_component) if block_given?

      render(field_component)
    end

    # Override Superform's submit to add Bootstrap styling and turbo support
    # @param value [String] the button text (defaults to submit_value)
    # @param options [Hash] submit button options
    # @option options [Boolean] :center center the button (default false)
    # @option options [String] :submits_with text shown while submitting
    # @option options [Symbol] :variant button variant (default `:default`).
    #   Valid values: `Components::ButtonStyling::BTN_VARIANTS`.
    # @option options [Symbol] :size button size modifier (optional).
    #   Valid values: `Components::ButtonStyling::BTN_SIZES.keys`.
    # @option options [Symbol] :as `:button` (default) renders
    #   `<button type="submit">value</button>`; `:input` renders
    #   `<input type="submit">`.
    # @option options [String] :class additional CSS classes
    # @option options [Hash] :data additional data attributes
    # `disable_with:` overrides the `data-disable-with` text (rails-ujs's
    # disabled-state label for non-Turbo submits). Defaults to the button
    # label (just disable, no text swap).
    def submit(value = submit_value, center: false, submits_with: nil, # rubocop:disable Metrics/ParameterLists
               disable_with: nil, variant: nil,
               size: nil, as: :button, **options)
      submits_with ||= default_submits_with(value)
      disable_with ||= value
      merged = submit_merged_options(options, variant: variant, size: size,
                                              center: center,
                                              submits_with: submits_with,
                                              disable_with: disable_with)
      if as == :button
        extra_class = "center-block my-3" if center
        # `options[:name]` is the HTML name= attribute on the button, NOT
        # the display text — keep it separate so it doesn't clobber `name:
        # value` (the label) in Button::Submit.
        html_name = options[:name] || "commit"
        render(Components::Button::Submit.new(
                 name: value,
                 html_name: html_name,
                 value: value,
                 variant: variant, size: size,
                 submits_with: submits_with,
                 disable_with: disable_with,
                 class: [extra_class, options[:class]].compact.
                        join(" ").presence,
                 **options.except(:class, :name)
               ))
      else
        super(value, **merged)
      end
    end

    private

    # Mirrors ERB `forms_helper.rb#submits_default_text`: an Update
    # button shows "Updating" while in-flight; anything else shows
    # "Submitting".
    def default_submits_with(value)
      value == :UPDATE.l ? :UPDATING.l : :SUBMITTING.l
    end

    def submit_merged_options(options, **opts)
      classes = ["btn", btn_class(opts[:variant]),
                 size_class(opts[:size]),
                 ("center-block my-3" if opts[:center]),
                 options[:class]].compact
      data = { turbo_submits_with: opts[:submits_with],
               disable_with: opts[:disable_with] }.merge(options[:data] || {})
      options.merge(class: classes.join(" "), data: data)
    end

    # Convert help: option to with_help slot for help icon rendering
    def set_help_slot(field_component, help_content)
      return if help_content.blank?

      field_component.with_help { help_content }
    end

    # Mirrors ERB `auto_label_if_form_is_account_prefs`: when `prefs: true`
    # is present, resolve the label from the `prefs_<field>` i18n key and
    # drop the `:prefs` option so it doesn't flow downstream. Used by the
    # same set of helpers the ERB applies it to: text, textarea, select,
    # checkbox, radio, number.
    def auto_label_for_prefs(field_name, options)
      return options if options[:prefs].blank?

      options.merge(label: :"prefs_#{field_name}".t).except(:prefs)
    end

    # Resolve a field name to a field object the factory methods can
    # call (`.text`, `.textarea`, `.checkbox`, etc.). Three paths:
    #
    # - **String** (e.g. `"member[lat]"`): standalone `FieldProxy`
    #   carrying the raw `name=` attribute and the given value. No
    #   model binding.
    # - **Symbol + explicit `value:`** (e.g. `text_field(:foo, value: x)`):
    #   route through `FieldProxy` with the Superform-namespaced name
    #   (`field(:foo).dom.name`) so the explicit `value:` overrides
    #   whatever `model.foo` would have produced. Matches Rails ERB's
    #   `f.text_field :foo, value: "override"` semantics, and lets
    #   forms use Symbol keys for fields whose `name=` belongs in the
    #   form's namespace but whose value comes from outside the model.
    # - **Symbol** (no `value:`): model-bound `Superform::Field`. Value
    #   reads through the field's own `.value` from the form's model
    #   / FormObject.
    #
    # Lets the `*_field` helpers handle bound and non-bound fields
    # through a single dispatch shape — the same precedent
    # `hidden_field` established.
    def resolve_field(field_name, value: nil)
      if field_name.is_a?(String)
        FieldProxy.new(nil, field_name, value)
      elsif !value.nil?
        # Symbol + value: build a FieldProxy that mirrors what
        # `field(field_name)` would have produced — namespace and key
        # kept SEPARATE so downstream components can slice
        # `dom.name` back into "model prefix" + "field key"
        # (matters for AutocompleterField's `model_namespace` and
        # `default_hidden_field_name`, which split on `[<key>]$`).
        # Walking `field(...).dom.name` and stripping the bracketed
        # field-key suffix recovers the namespace.
        superform_name = field(field_name).dom.name
        key_suffix = "[#{field_name}]"
        namespace = superform_name.delete_suffix(key_suffix)
        FieldProxy.new(namespace, field_name, value)
      else
        field(field_name)
      end
    end
  end
end

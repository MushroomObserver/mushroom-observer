# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Mixin providing all Bootstrap-styled field helper methods.
  # Included by Components::ApplicationForm; requires the including class
  # to provide Superform's +field+ and +render+ methods.
  #
  # Consult this file (alongside +application_form.rb+) to see the full
  # set of field helpers available in form components.
  module FieldHelpers
    # Wrapper option keys that should not be passed to the field itself
    WRAPPER_OPTIONS = [:label, :help, :prefs, :inline, :wrap_class,
                       :wrap_data, :between, :button, :button_data,
                       :button_text, :addon, :monospace, :label_class,
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

      field_component = field(field_name).text(
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

      field_component = field(field_name).textarea(
        wrapper_options: wrapper_opts,
        **field_opts
      )

      set_help_slot(field_component, wrapper_opts[:help])
      yield(field_component) if block_given?

      render(field_component)
    end

    # Checkbox field with label and Bootstrap checkbox wrapper
    # @param field_name [Symbol] the field name
    # @param options [Hash] all field and wrapper options
    # Wrapper options: :label, :prefs, :class_name
    # @yield [field_component] Optional block to set slots:
    #   `with_between`, `with_append`, `with_help`
    def checkbox_field(field_name, **options, &block)
      options = auto_label_for_prefs(field_name, options)
      wrapper_opts = options.slice(*WRAPPER_OPTIONS)
      field_opts = options.except(*WRAPPER_OPTIONS)

      field_component = field(field_name).checkbox(
        wrapper_options: wrapper_opts,
        **field_opts
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

      field_component = field(field_name).radio(
        *choices,
        wrapper_options: wrapper_opts,
        **field_opts
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

      field_component = field(field_name).select(
        options_list,
        wrapper_options: wrapper_opts,
        **field_opts
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

      field_component = field(field_name).date(
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

      field_component = field(field_name).text(
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
      # Both paths render through `HiddenField` — the dedicated
      # hidden-input component. `HiddenField` only needs `.dom.id`,
      # `.dom.name`, `.value` on its `field` argument; Superform's
      # `Field` and our `FieldProxy` both provide them. So the
      # Symbol path can pass the Superform field directly — no
      # FieldProxy rebuild, value auto-reads from model / FormObject
      # via the field's own `.value`.
      f = if field_name.is_a?(String)
            FieldProxy.new(nil, field_name, options[:value])
          else
            field(field_name)
          end
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

      field_component = field(field_name).text(
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

      field_component = field(field_name).static(
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

      field_component = field(field_name).read_only(
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

      field_component = field(field_name).file(
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

      field_component = field(field_name).autocompleter(
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
    # @option options [String] :btn_class Bootstrap button class
    #   (default `"btn-default"`). Pass the full class name, e.g.
    #   `"btn-outline-default"` to match the top-nav search bar style.
    # @option options [Symbol] :as `:input` (default) renders
    #   `<input type="submit">`; `:button` renders
    #   `<button type="submit">value</button>`.
    # @option options [String] :class additional CSS classes
    # @option options [Hash] :data additional data attributes
    # `disable_with:` overrides the `data-disable-with` text (rails-ujs's
    # disabled-state label for non-Turbo submits). Defaults to the button
    # label (just disable, no text swap).
    def submit(value = submit_value, center: false, submits_with: nil, # rubocop:disable Metrics/ParameterLists
               disable_with: nil, btn_class: "btn-default", as: :input,
               **options)
      submits_with ||= :SUBMITTING.l
      disable_with ||= value
      classes = ["btn", btn_class]
      classes << "center-block my-3" if center
      classes << options[:class] if options[:class].present?

      data = { turbo_submits_with: submits_with,
               disable_with: disable_with }.merge(options[:data] || {})
      merged = options.merge(class: classes.join(" "), data: data)

      if as == :button
        button(type: "submit", name: "commit", **merged) { value }
      else
        super(value, **merged)
      end
    end

    private

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
  end
end

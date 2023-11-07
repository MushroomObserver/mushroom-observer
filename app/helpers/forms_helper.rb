# frozen_string_literal: true

#  custom_file_field            # stylable file input field with
#                               # client-side size validation
#  date_select_opts

# helpers for form tags
module FormsHelper
  # Bootstrap submit button
  # <%= submit_button(form: f, button: button.t, center: true) %>
  def submit_button(**args)
    unless args[:form].is_a?(ActionView::Helpers::FormBuilder)
      return args[:button]
    end

    opts = args.except(:form, :button, :class, :center)
    opts[:class] = "btn btn-default"
    opts[:class] += " center-block my-3" if args[:center] == true
    opts[:class] += " #{args[:class]}" if args[:class].present?

    args[:form].submit(args[:button], opts)
  end

  # form-agnostic button, type=button
  def js_button(**args)
    opts = args.except(:form, :button, :class, :center)
    opts[:class] = "btn btn-default"
    opts[:class] += " center-block my-3" if args[:center] == true
    opts[:class] += " #{args[:class]}" if args[:class].present?

    button_tag(args[:button], type: :button, **opts)
  end

  # Form field builders with labels, consistent styling and less template code!
  # Pass everything as a keyword argument, no positional args.
  #
  # Required args:
  # `form`  instance of ActionView::Helpers::FormBuilder
  #         e.g. `form_with(model: @observation) do |f|`
  #              the builder is assigned to `f`
  # `field` field name. Will be nested if form_builder is passing a
  #         @model object or a `fields_for` object
  #         e.g. in the observation form, `form: f, field: :location`
  #              creates `<input name="observation[location]"`
  #
  # Optional args:
  # `label`   label text, can be HTML
  # `prefs`   set to `true` to infer the label translation string from the pref
  # `class`   additional classes for the form-group wrap
  # `inline`  set to `true` for inline label and input
  # `between` additional HTML between the label and the input
  # `append`  additional HTML after the input
  #
  # Other args per method as appropriate.
  # The methods should separate pass-through field options (e.g. data, onclick,
  # `textarea` rows, `checkbox` checked, value, disabled) from the args that are
  # necessary for the Rails form_builder, and position them correctly, using the
  # `separate_field_options_from_args` method.
  #
  # Consequently, certain methods need special kwargs.
  # In the case that the Rails form builder needs a positional arg, e.g.
  # radio(value:) and select(options: [], select_opts: {}), check the method
  # below for the appropriate special kwargs.

  # Bootstrap checkbox: form, field, label, class,
  # Can also pass checkbox options: checked, value, disabled, data, etc.
  # NOTE: Only need to set `checked` if state not inferrable from db field name
  # (i.e. a model attribute of the form_with(@model))
  # How to use:
  # <%= check_box_with_label(form: f, field: :no_emails, prefs: true) %>
  #
  def check_box_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    opts = separate_field_options_from_args(args)

    wrap_class = form_group_wrap_class(args, "checkbox")

    tag.div(class: wrap_class) do
      args[:form].label(args[:field]) do
        concat(args[:form].check_box(args[:field], opts))
        concat(args[:label])
      end
    end
  end

  # Bootstrap radio: form, field, value, label, class, checked
  def radio_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    opts = separate_field_options_from_args(args, [:value])

    wrap_class = form_group_wrap_class(args, "radio")

    tag.div(class: wrap_class) do
      args[:form].label("#{args[:field]}_#{args[:value]}") do
        concat(args[:form].radio_button(args[:field], args[:value], opts))
        concat(args[:label])
      end
    end
  end

  # Bootstrap text_field
  def text_field_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    args = check_for_optional_or_required_note(args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control"

    wrap_class = form_group_wrap_class(args)
    label_opts = field_label_opts(args)

    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], label_opts))
      concat(args[:between]) if args[:between].present?
      concat(args[:form].text_field(args[:field], opts))
      concat(args[:append]) if args[:append].present?
    end
  end

  # For the moment "year autocompleters" have to use data attributes,
  # but TODO: eliminate all of them, in favor of a new stimulus controller
  # that will just turn them into text fields.
  # Jason agrees that nobody needs a year autocompleter, and they complicate
  # the autocompleter js too. - AN 20231103
  #
  # This allows incoming data attributes to deep_merge with autocompleter's data
  def autocompleter_field(**args)
    autocompleter_args = {
      placeholder: :start_typing.l,
      data: { controller: :autocompleter, autocomplete: args[:autocomplete],
              separator: args[:separator] }
    }
    autocompleter_args = args.except(:autocomplete, :separator, :textarea).
                         deep_merge(autocompleter_args)

    if args[:textarea] == true
      text_area_with_label(**autocompleter_args)
    else
      text_field_with_label(**autocompleter_args)
    end
  end

  # Bootstrap text_area
  def text_area_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    args = check_for_optional_or_required_note(args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control"
    opts[:class] += " text-monospace" if args[:monospace].present?

    wrap_class = form_group_wrap_class(args)
    label_opts = field_label_opts(args)

    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], label_opts))
      concat(args[:between]) if args[:between].present?
      concat(args[:form].text_area(args[:field], opts))
      concat(args[:append]) if args[:append].present?
    end
  end

  # Bootstrap select.
  # Works for select_year but not date_select, which generates multiple selects
  def select_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    args = select_generate_default_options(args)
    args = check_for_optional_or_required_note(args)

    opts = separate_field_options_from_args(
      args, [:options, :select_opts, :start_year, :end_year]
    )
    opts[:class] = "form-control"
    opts[:class] += " w-auto" if args[:width] == :auto

    wrap_class = form_group_wrap_class(args)
    label_opts = field_label_opts(args)

    # debugger
    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], label_opts))
      concat(args[:between]) if args[:between].present?
      concat(args[:form].select(args[:field], args[:options],
                                args[:select_opts], opts))
      concat(args[:append]) if args[:append].present?
    end
  end

  # default select_opts - also generate year options if start_year given
  def select_generate_default_options(args)
    args[:select_opts] ||= (args[:value] ? { selected: args[:value] } : {})

    return args unless args[:start_year].present? && args[:end_year].present?

    args[:options] = args[:end_year].downto(args[:start_year])
    args
  end

  # Bootstrap number_field
  def number_field_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control"
    opts[:min] ||= 1

    wrap_class = form_group_wrap_class(args)

    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:form].number_field(args[:field], opts))
    end
  end

  # Bootstrap password_field
  def password_field_with_label(**args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control"
    opts[:value] ||= ""

    wrap_class = form_group_wrap_class(args)

    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:form].password_field(args[:field], opts))
    end
  end

  # Bootstrap email_field. Unused because our email fields are text fields
  # def email_field_with_label(**args)
  #   opts = separate_field_options_from_args(args)
  #   opts[:class] = "form-control"
  #   opts[:value] ||= ""

  #   wrap_class = form_group_wrap_class(args)

  #   tag.div(class: wrap_class) do
  #     concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
  #     concat(args[:form].email_field(args[:field], opts))
  #   end
  # end

  # We have fields like this. Prints a static value for submitted field,
  # from either a "text" option (first choice) or a "value" option
  def hidden_field_with_label(**args)
    opts = separate_field_options_from_args(args)
    text = opts[:text] || opts[:value] || ""

    wrap_class = form_group_wrap_class(args)

    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(tag.p(text, class: "form-control-static"))
      concat(args[:form].hidden_field(args[:field], opts))
    end
  end

  # Bootstrap allows you to style static text like this:
  def static_text_with_label(**args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control-static"
    text = opts[:text] || opts[:value] || ""
    opts.delete(:value)

    wrap_class = form_group_wrap_class(args)

    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(tag.p(text, **opts))
    end
  end

  # Bootstrap url_field
  def url_field_with_label(**args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control"
    opts[:value] ||= ""

    wrap_class = form_group_wrap_class(args)

    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:form].url_field(args[:field], opts))
    end
  end

  # Bootstrap file input field with client-side size validation.
  def file_field_with_label(**args)
    opts = separate_field_options_from_args(args)
    input_span_class = "file-field btn btn-default"
    max_size = MO.image_upload_max_size
    max_size_in_mb = (max_size.to_f / 1024 / 1024).round
    opts = opts.merge(
      max_upload_msg: :validate_image_file_too_big.l(max: max_size_in_mb),
      max_upload_size: max_size
    )

    wrap_class = form_group_wrap_class(args)

    # append is always :no_file_selected.t
    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:between]) if args[:between].present?
      concat(
        tag.span(class: input_span_class) do
          concat(:select_file.t)
          concat(args[:form].file_field(args[:field], opts))
        end
      )
      concat(tag.span(:no_file_selected.t))
    end
  end

  # To be retired in favor of the above:
  # Create stylable file input field with client-side size validation.
  def custom_file_field(obj, attr, opts = {})
    max_size = MO.image_upload_max_size
    max_size_in_mb = (max_size.to_f / 1024 / 1024).round
    file_field = file_field(
      obj,
      attr,
      opts.merge(
        max_upload_msg: :validate_image_file_too_big.l(max: max_size_in_mb),
        max_upload_size: max_size
      )
    )
    tag.span(:select_file.t + file_field, class: "file-field btn btn-default") +
      tag.span(:no_file_selected.t)
  end

  # Unused
  # def search_field_with_submit(args)
  #   opts = separate_field_options_from_args(args)
  #   opts[:class] = "form-control"
  #   opts[:value] ||= ""
  #   opts[:placeholder] ||= args[:label]

  #   args[:inline] = true
  #   wrap_class = form_group_wrap_class(args)

  #   tag.div(class: wrap_class) do
  #     concat(args[:form].label(args[:field], args[:label],
  #                              class: "mr-3 sr-only"))
  #     concat(
  #       tag.div(class: "input-group") do
  #         concat(args[:form].text_field(args[:field], opts))
  #         concat(
  #           tag.span(class: "input-group-btn") do
  #             submit_button(form: args[:form], button: :SEARCH.l)
  #           end
  #         )
  #       end
  #     )
  #   end
  # end

  # convenience for account prefs: auto-populates label text arg
  def auto_label_if_form_is_account_prefs(args)
    return args if args[:prefs].blank?

    args = args.merge({ label: :"prefs_#{args[:field]}".t })
    args.except(:prefs)
  end

  # convenience for the bootstrap "form-group" wrap class.
  # needs "form-inline" for an inline label + field
  # Note that wrap is not always "form-group", e.g. "checkbox"
  def form_group_wrap_class(args, base = "form-group")
    wrap_class = base

    # checkbox and radio do not need explicit `form-inline` class
    if (args[:inline] == true) && (base == "form-group")
      wrap_class += " form-inline"
    end

    wrap_class += " #{args[:class]}" if args[:class].present?
    wrap_class
  end

  def field_label_opts(args)
    label_opts = { class: "mr-3" }
    label_opts[:index] = args[:index] if args[:index].present?
    label_opts
  end

  # shorthand to set a between or append string with (optional) or (required)
  # use:       between: :optional, append: :required
  def check_for_optional_or_required_note(args)
    return args unless args[:between].present? || args[:append].present?

    positions = [:between, :append].freeze
    keys = [:optional, :required].freeze
    positions.each do |pos|
      keys.each do |key|
        args[pos] = help_note(:span, "(#{key.t})") if args[pos] == key
      end
    end
    args
  end

  # These are args that should not be passed to the field
  # Note that :value is sometimes explicitly passed, so it must
  # be excluded separately (not here)
  def separate_field_options_from_args(args, extras = [])
    exceptions = [
      :form, :field, :label, :class, :width, :inline, :between, :append,
      :optional, :required, :monospace, :type
    ] + extras

    args.clone.except(*exceptions)
  end

  def date_select_opts(obj = nil)
    start_year = 20.years.ago.year
    init_value = obj.try(&:when).try(&:year)
    start_year = init_value if init_value && init_value < start_year
    { start_year: start_year,
      end_year: Time.zone.now.year,
      selected: obj.try(&:when) || Time.zone.today,
      order: [:day, :month, :year] }
  end
end

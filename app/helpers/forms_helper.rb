# frozen_string_literal: true

#  custom_file_field            # stylable file input field with
#                               # client-side size validation
#  date_select_opts

# helpers for form tags

module FormsHelper # rubocop:disable Metrics/ModuleLength
  # Bootstrap submit button
  # <%= submit_button(form: f, button: button.t, center: true) %>
  def submit_button(**args)
    unless args[:form].is_a?(ActionView::Helpers::FormBuilder)
      return args[:button]
    end

    # custom text for the button while submitting
    submits_with = args[:submits_with] || submits_default_text(args[:button])
    data = args[:data] || {}

    opts = args.except(:form, :button, :class, :center, :data, :submits_with)
    opts[:class] = "btn btn-default"
    opts[:class] += " center-block my-3" if args[:center] == true
    opts[:class] += " #{args[:class]}" if args[:class].present?
    opts[:data] = { turbo_submits_with: submits_with }.deep_merge(data)

    args[:form].submit(args[:button], opts)
  end

  def submits_default_text(button_text)
    if button_text == :UPDATE.l
      :UPDATING.l
    else
      :SUBMITTING.l
    end
  end

  # form-agnostic button, type=button
  def js_button(**args, &block)
    button = block ? capture(&block) : args[:button]
    opts = args.except(:form, :button, :class, :center)
    opts[:class] = "btn btn-default"
    opts[:class] += " center-block my-3" if args[:center] == true
    opts[:class] += " #{args[:class]}" if args[:class].present?

    button_tag(button, type: :button, **opts)
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
    args = check_for_help_block(args)
    opts = separate_field_options_from_args(args)

    wrap_class = form_group_wrap_class(args, "checkbox")

    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field]) do
        concat(args[:form].check_box(args[:field], opts,
                                     args[:checked_value] || "1",
                                     args[:unchecked_value] || "0"))
        concat(args[:label])
        concat(args[:between]) if args[:between].present?
      end)
      concat(args[:append]) if args[:append].present?
    end
  end

  # Makes an element that looks like a bootstrap button but works as a checkbox.
  # Only works within a .btn-group wrapper. NOTE: Different from a check_box!
  def check_button_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    opts = separate_field_options_from_args(args)

    wrap_class = form_group_wrap_class(args, "btn btn-default btn-sm")

    args[:form].label(args[:field], class: wrap_class) do
      [args[:form].check_box(args[:field], opts.merge(class: "mt-0 mr-2")),
       args[:label]].safe_join
    end
  end

  # Bootstrap radio: form, field, value, label, class, checked
  def radio_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    args = check_for_help_block(args)
    opts = separate_field_options_from_args(args, [:value])

    wrap_class = form_group_wrap_class(args, "radio")

    tag.div(class: wrap_class) do
      concat(args[:form].label("#{args[:field]}_#{args[:value]}") do
        concat(args[:form].radio_button(args[:field], args[:value], opts))
        concat(args[:label])
        if args[:between].present?
          concat(tag.div(class: "d-inline-block ml-3") { args[:between] })
        end
      end)
      concat(args[:append]) if args[:append].present?
    end
  end

  # Makes an element that looks like a bootstrap button but works as a radio.
  # Only works within a .btn-group wrapper. NOTE: Different from a radio_button!
  def radio_button_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    opts = separate_field_options_from_args(args)

    wrap_class = form_group_wrap_class(args, "btn btn-default btn-sm")

    args[:form].label(args[:field], class: wrap_class) do
      [args[:form].radio_button(args[:field], opts.merge(class: "mt-0 mr-2")),
       args[:label]].safe_join
    end
  end

  # Bootstrap text_field
  def text_field_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    args = check_for_optional_or_required_note(args)
    args = check_for_help_block(args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control"

    wrap_class = form_group_wrap_class(args)
    wrap_data = args[:wrap_data] || {}
    label_opts = field_label_opts(args)
    label_opts[:class] = class_names(label_opts[:class], args[:label_class])

    tag.div(class: wrap_class, data: wrap_data) do
      concat(text_label_row(args, label_opts))
      if args[:addon].present? # text addon, not interactive
        concat(tag.div(class: "input-group") do
          concat(args[:form].text_field(args[:field], opts))
          concat(tag.span(args[:addon], class: "input-group-addon"))
        end)
      elsif args[:button].present? # button addon, interactive
        concat(tag.div(class: "input-group") do
          concat(args[:form].text_field(args[:field], opts))
          concat(tag.span(class: "input-group-btn") do
            js_button(button: args[:button], class: "btn btn-default",
                      data: args[:button_data] || {})
          end)
        end)
      else
        concat(args[:form].text_field(args[:field], opts))
      end
      concat(args[:append]) if args[:append].present?
    end
  end

  # Bootstrap text_area
  def text_area_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    args = check_for_optional_or_required_note(args)
    args = check_for_help_block(args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control"
    opts[:class] += " text-monospace" if args[:monospace].present?

    wrap_class = form_group_wrap_class(args)
    wrap_data = args[:wrap_data] || {}
    label_opts = field_label_opts(args)

    tag.div(class: wrap_class, data: wrap_data) do
      concat(text_label_row(args, label_opts))
      concat(args[:form].text_area(args[:field], opts))
      concat(args[:append]) if args[:append].present?
    end
  end

  # The label row for autocompleters is potentially complicated, many buttons.
  # Content for `between` and `label_after` come right after the label on left,
  # content for `label_end` is at the end of the same line, right justified.
  def text_label_row(args, label_opts)
    display = args[:inline] == true ? "d-inline-flex" : "d-flex"
    tag.div(class: "#{display} justify-content-between") do
      concat(tag.div do
        concat(args[:form].label(args[:field], args[:label], label_opts))
        concat(args[:between]) if args[:between].present?
        concat(args[:label_after]) if args[:label_after].present?
      end)
      concat(tag.div do
        concat(args[:label_end]) if args[:label_end].present?
      end)
    end
  end

  # Bootstrap select.
  # Works for select_year but not date_select, which generates multiple selects
  def select_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    args = select_year_default_options(args)
    select_opts = select_helper_opts(args)
    args = check_for_optional_or_required_note(args)
    args = check_for_help_block(args)

    opts = separate_field_options_from_args(
      args, [:options, :select_opts, :start_year, :end_year]
    )
    opts[:class] = "form-control"
    opts[:class] += " w-auto" if args[:width] == :auto

    wrap_class = form_group_wrap_class(args)
    label_opts = field_label_opts(args)

    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], label_opts))
      concat(args[:between]) if args[:between].present?
      concat(args[:form].select(args[:field], args[:options],
                                select_opts, opts))
      concat(args[:append]) if args[:append].present?
    end
  end

  # Generate `year` options if start_year given
  def select_year_default_options(args)
    return args unless args[:start_year].present? && args[:end_year].present?

    args[:options] = args[:end_year].downto(args[:start_year])
    args
  end

  # Args specific to the Rails select helper.
  # selected: nil could mean no selected value, or a selected value of nil.
  def select_helper_opts(args)
    { include_blank: args[:include_blank], selected: args[:selected] }
  end

  # MO mostly uses year-input_controller to switch the year selects to
  # text inputs, but you can pass data: { controller: "" } to get a year select.
  # The three "selects" will always be inline, but pass inline: true to make
  # the label and selects inline.
  # The form label does not correspond exactly to any of the three fields, so
  # it identifies the wrapping div. (That's also valid HTML.)
  # https://stackoverflow.com/a/16426122/3357635
  def date_select_with_label(**args)
    args = check_for_optional_or_required_note(args)
    args = check_for_help_block(args)
    opts = separate_field_options_from_args(args, [:object, :data])
    opts[:class] = "form-control"
    opts[:data] = { controller: "year-input" }.merge(args[:data] || {})
    date_opts = date_select_opts(args)
    wrap_class = form_group_wrap_class(args)
    selects_class = "form-inline date-selects"
    selects_class += " d-inline-block" if args[:inline] == true
    label_opts = { class: "mr-3" }
    label_opts[:index] = args[:index] if args[:index].present?
    tag.div(class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], label_opts))
      concat(args[:between]) if args[:between].present?
      date_select_div(args, date_opts, opts, selects_class)
      concat(args[:append]) if args[:append].present?
    end
  end

  # The index arg is for multiple date_selects in a form
  def date_select_opts(args = {})
    field = args[:field] || :when
    obj = args[:object] || args[:form]&.object || nil
    start_year = args[:start_year] || 20.years.ago.year
    end_year = args[:end_year] || Time.zone.now.year
    selected = args[:selected] || Time.zone.today
    # The field may not be an attribute of the object
    if obj.present? && obj.respond_to?(field)
      init_year = obj.try(&field.to_sym).try(&:year)
      selected = obj.try(&field.to_sym) || Time.zone.today
    end
    if init_year && init_year < start_year && init_year > 1900
      start_year = init_year
    end
    opts = { start_year:, end_year:, selected:,
             include_blank: args[:include_blank], default: args[:default],
             order: args[:order] || [:day, :month, :year] }
    opts[:index] = args[:index] if args[:index].present?
    opts
  end

  # If there's no form object_name, we need a name and id for the fields.
  # Turns out you have to use a different Rails helper, select_date, for this.
  def date_select_div(args, date_opts, opts, selects_class)
    if args[:form].object_name.present?
      identifier = [args[:form]&.object_name, args[:index],
                    args[:field]].compact.join("_")
      concat(tag.div(class: selects_class, id: identifier) do
        concat(args[:form].date_select(args[:field], date_opts, opts))
      end)
    else
      concat(tag.div(class: selects_class, id: args[:field]) do
        concat(select_date(date_opts[:selected],
                           date_opts.merge(prefix: args[:field]), opts))
      end)
    end
  end

  # Bootstrap number_field
  def number_field_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    args = check_for_help_block(args)
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
    args = check_for_help_block(args)
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
    args = check_for_help_block(args)
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
  # This could be redone as an input group with a "browse" button, in BS4.
  def file_field_with_label(**args)
    args = check_for_help_block(args)
    opts = separate_field_options_from_args(args)
    input_span_class = "file-field btn btn-default"
    max_size = MO.image_upload_max_size
    max_size_in_mb = (max_size.to_f / 1024 / 1024).round
    max_upload_msg = :validate_image_file_too_big.l(max: max_size_in_mb)
    opts = opts.merge(
      data: {
        action: "change->file-input#validate", file_input_target: "input",
        max_upload_size: max_size, max_upload_msg: max_upload_msg
      }
    )

    wrap_class = form_group_wrap_class(args)

    # append is always :no_file_selected.t
    tag.div(class: wrap_class, data: { controller: "file-input" }) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:between]) if args[:between].present?
      concat(
        tag.span(class: input_span_class) do
          concat(:select_file.t)
          concat(args[:form].file_field(args[:field], opts))
        end
      )
      concat(tag.span(:no_file_selected.t, data: { file_input_target: "name" }))
    end
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
    label_opts = {}
    label_opts[:index] = args[:index] if args[:index].present?
    label_opts[:class] = "mr-3" if args[:inline].present?
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
        if args[pos] == key
          args[pos] = help_note(:span, "(#{key.l})", class: "ml-3")
        end
      end
    end
    args
  end

  # Adds a help block to the field, with a collapse trigger beside the label.
  def check_for_help_block(args)
    unless args[:help].present? && args[:field].present? && args[:form].present?
      return args
    end

    need_margin = args[:inline].present?
    between_class = need_margin ? "mr-3" : ""
    trigger_class = need_margin ? "" : "ml-3"

    id = [
      nested_field_id(args),
      "help"
    ].compact_blank.join("_")
    args[:between] = capture do
      tag.span(class: between_class) do
        if args[:between].present?
          concat(tag.span(class: "ml-3") { args[:between] })
        end
        concat(collapse_info_trigger(id, class: trigger_class))
      end
    end
    args[:append] = capture do
      concat(args[:append])
      concat(collapse_help_block(nil, id:) do
        concat(args[:help])
      end)
    end
    args
  end

  def nested_field_id(args)
    [args[:form].object_name.to_s.id_of_nested_field,
     args[:field].to_s].compact_blank.join("_")
  end

  # These are args that should not be passed to the field
  # Note that :value is sometimes explicitly passed, so it must
  # be excluded separately (not here)
  def separate_field_options_from_args(args, extras = [])
    exceptions = [
      :form, :field, :label, :class, :width, :inline, :between, :label_after,
      :label_end, :append, :help, :addon, :optional, :required, :monospace,
      :type, :wrap_data, :wrap_id, :button, :button_data, :checked_value,
      :unchecked_value, :hidden_name
    ] + extras

    args.clone.except(*exceptions)
  end
end

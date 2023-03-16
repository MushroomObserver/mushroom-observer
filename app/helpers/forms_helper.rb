# frozen_string_literal: true

# helpers for form tags
module FormsHelper
  # make a help-note styled element, like a div, p, or span
  def help_note(element = :span, string = "")
    content_tag(element, string, class: "help-note")
  end

  # make a help-block styled element, like a div, p
  def help_block(element = :div, string = "")
    content_tag(element, string, class: "help-block")
  end

  # draw a help block with an arrow
  def help_block_with_arrow(direction = nil, **args, &block)
    div_class = "well well-sm help-block position-relative"
    div_class += " mt-3" if direction == "up"

    content_tag(:div, class: div_class,
                      id: args[:id]) do
      concat(capture(&block).to_s)
      if direction
        arrow_class = "arrow-#{direction}"
        arrow_class += " hidden-xs" unless args[:mobile]
        concat(content_tag(:div, "", class: arrow_class))
      end
    end
  end

  def panel_with_outer_heading(**args, &block)
    html = []
    h_tag = (args[:h_tag].presence || :h4)
    html << content_tag(h_tag, args[:heading]) if args[:heading]
    html << panel_block(**args, &block)
    safe_join(html)
  end

  def panel_block(**args, &block)
    content_tag(
      :div,
      class: "panel panel-default #{args[:class]}",
      id: args[:id]
    ) do
      content_tag(:div, class: "panel-body #{args[:inner_class]}") do
        concat(capture(&block).to_s)
      end
    end
  end

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

    content_tag(:div, class: wrap_class) do
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

    content_tag(:div, class: wrap_class) do
      args[:form].label("#{args[:field]}_#{args[:value]}") do
        concat(args[:form].radio_button(args[:field], args[:value], opts))
        concat(args[:label])
      end
    end
  end

  # Bootstrap text_field
  def text_field_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control"

    wrap_class = form_group_wrap_class(args)

    content_tag(:div, class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:between]) if args[:between].present?
      concat(args[:form].text_field(args[:field], opts))
      concat(args[:append]) if args[:append].present?
    end
  end

  # Bootstrap text_area
  def text_area_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control"

    wrap_class = form_group_wrap_class(args)

    content_tag(:div, class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:between]) if args[:between].present?
      concat(args[:form].text_area(args[:field], opts))
      concat(args[:append]) if args[:append].present?
    end
  end

  # Bootstrap select.
  # Works for select_year
  def select_with_label(**args)
    args = auto_label_if_form_is_account_prefs(args)
    args = select_generate_default_options(args)

    opts = separate_field_options_from_args(
      args, [:options, :select_opts, :start_year, :end_year]
    )
    opts[:class] = "form-control"
    opts[:class] += " w-auto" if args[:width] == :auto

    wrap_class = form_group_wrap_class(args)

    content_tag(:div, class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:between]) if args[:between].present?
      concat(args[:form].select(args[:field], args[:options],
                                args[:select_opts], opts))
      concat(args[:append]) if args[:append].present?
    end
  end

  # default select_opts - also generate year options if start_year given
  def select_generate_default_options(args)
    args[:select_opts] ||= {}

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

    content_tag(:div, class: wrap_class) do
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

    content_tag(:div, class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:form].password_field(args[:field], opts))
    end
  end

  # Bootstrap email_field. Unused because our email fields are text fields
  def email_field_with_label(**args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control"
    opts[:value] ||= ""

    wrap_class = form_group_wrap_class(args)

    content_tag(:div, class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:form].email_field(args[:field], opts))
    end
  end

  # Bootstrap url_field
  def url_field_with_label(**args)
    opts = separate_field_options_from_args(args)
    opts[:class] = "form-control"
    opts[:value] ||= ""

    wrap_class = form_group_wrap_class(args)

    content_tag(:div, class: wrap_class) do
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
    content_tag(:div, class: wrap_class) do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:between]) if args[:between].present?
      concat(
        content_tag(:span, class: input_span_class) do
          concat(:select_file.t)
          concat(args[:form].file_field(args[:field], opts))
        end
      )
      concat(content_tag(:span, :no_file_selected.t))
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
    content_tag(:span, :select_file.t + file_field,
                class: "file-field btn btn-default") +
      content_tag(:span, :no_file_selected.t)
  end

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

  # These are args that should not be passed to the field
  # Note that :value is sometimes explicitly passed, so it must
  # be excluded separately (not here)
  def separate_field_options_from_args(args, extras = [])
    exceptions = [
      :form,
      :field,
      :label,
      :class,
      :width,
      :inline,
      :between,
      :append
    ] + extras

    args.clone.except(*exceptions)
  end

  def date_select_opts(obj = nil)
    start_year = 20.years.ago.year
    init_value = obj.try(&:when).try(&:year)
    start_year = init_value if init_value && init_value < start_year
    { start_year: start_year,
      end_year: Time.zone.now.year,
      order: [:day, :month, :year] }
  end
end

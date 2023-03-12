# frozen_string_literal: true

# helpers for form tags
module FormsHelper
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

  # convenience for account prefs: auto-populates label text arg
  def check_if_prefs(args)
    return args if args[:prefs].blank?

    args = args.merge({ label: :"prefs_#{args[:field]}".t + ":" })
    args.except(:prefs)
  end

  # Bootstrap checkbox: form, field, label, class,
  # checkbox options: checked, value, disabled, data, etc.
  # NOTE: Only need to set `checked` if state not inferrable from db field name
  # (i.e. a model attribute of the form_with(@model))
  def check_box_with_label(**args)
    args = check_if_prefs(args)
    opts = args.except(:form, :field, :label, :class)

    content_tag(:div, class: "checkbox #{args[:class]}") do
      args[:form].label(args[:field]) do
        concat(args[:form].check_box(args[:field], opts))
        concat(args[:label])
      end
    end
  end

  # Bootstrap radio: form, field, value, label, class, checked
  def radio_with_label(**args)
    args = check_if_prefs(args)
    opts = args.except(:form, :field, :value, :label, :class)

    content_tag(:div, class: "radio #{args[:class]}") do
      args[:form].label("#{args[:field]}_#{args[:value]}") do
        concat(args[:form].radio_button(args[:field], args[:value], opts))
        concat(args[:label])
      end
    end
  end

  # Bootstrap text_field
  def text_field_with_label(**args)
    args = check_if_prefs(args)
    opts = args.except(:form, :field, :label, :class, :inline)
    opts[:class] = "form-control"

    args[:class] ||= ""
    args[:class] += " form-inline" if args[:inline] == true

    content_tag(:div, class: "form-group #{args[:class]}") do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:between]) if args[:between].present?
      concat(args[:form].text_field(args[:field], opts))
      concat(args[:append]) if args[:append].present?
    end
  end

  # Bootstrap text_area
  def text_area_with_label(**args)
    args = check_if_prefs(args)
    opts = args.except(:form, :field, :label, :class, :inline)
    opts[:class] = "form-control"

    args[:class] ||= ""
    args[:class] += " form-inline" if args[:inline] == true

    content_tag(:div, class: "form-group #{args[:class]}") do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:between]) if args[:between].present?
      concat(args[:form].text_area(args[:field], opts))
      concat(args[:append]) if args[:append].present?
    end
  end

  # Bootstrap select
  def select_with_label(**args)
    args = check_if_prefs(args)
    opts = args.except(:form, :field, :options, :label, :class, :inline,
                       :select_opts)
    opts[:class] = "form-control"
    opts[:class] += " w-auto" if args[:width] == :auto

    args[:class] ||= ""
    args[:class] += " form-inline" if args[:inline] == true
    args[:select_opts] ||= {}

    content_tag(:div, class: "form-group #{args[:class]}") do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:between]) if args[:between].present?
      concat(args[:form].select(args[:field], args[:options],
                                args[:select_opts], opts))
      concat(args[:append]) if args[:append].present?
    end
  end

  # Bootstrap number_field
  def number_field_with_label(**args)
    args = check_if_prefs(args)
    opts = args.except(:form, :field, :label, :class, :inline)
    opts[:class] = "form-control"
    opts[:min] ||= 1

    args[:class] ||= ""
    args[:class] += " form-inline" if args[:inline] == true

    content_tag(:div, class: "form-group #{args[:class]}") do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:form].number_field(args[:field], opts))
    end
  end

  # Bootstrap password_field
  def password_field_with_label(**args)
    opts = args.except(:form, :field, :label, :class, :inline)
    opts[:class] = "form-control"
    opts[:value] ||= ""

    args[:class] ||= ""
    args[:class] += " form-inline" if args[:inline] == true

    content_tag(:div, class: "form-group #{args[:class]}") do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:form].password_field(args[:field], opts))
    end
  end

  # Bootstrap email_field
  def email_field_with_label(**args)
    opts = args.except(:form, :field, :label, :class, :inline)
    opts[:class] = "form-control"
    opts[:value] ||= ""

    args[:class] ||= ""
    args[:class] += " form-inline" if args[:inline] == true

    content_tag(:div, class: "form-group #{args[:class]}") do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:form].email_field(args[:field], opts))
    end
  end

  # Bootstrap url_field
  def url_field_with_label(**args)
    opts = args.except(:form, :field, :label, :class, :inline)
    opts[:class] = "form-control"
    opts[:value] ||= ""

    args[:class] ||= ""
    args[:class] += " form-inline" if args[:inline] == true

    content_tag(:div, class: "form-group #{args[:class]}") do
      concat(args[:form].label(args[:field], args[:label], class: "mr-3"))
      concat(args[:form].url_field(args[:field], opts))
    end
  end
end

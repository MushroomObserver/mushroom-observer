# frozen_string_literal: true

#  textilize_without_paragraph  # override Rails method of same name
#  textilize                    # override Rails method of same name
#  safe_br                      # <br/>,html_safe
#  safe_empty
#  safe_nbsp
#  escape_html                  # Return escaped HTML
#  indent                       # in-lined white-space element of n pixels
#  content_tag_if
#  content_tag_unless
#  add content_help             # help text viewable on mouse-over

# helpers for content tags
module ContentHelper
  def safe_empty
    "".html_safe
  end

  def safe_br
    "<br/>".html_safe
  end

  def safe_nbsp
    "&nbsp;".html_safe
  end

  # Create an in-line white-space element approximately the given width in
  # pixels.  It should be non-line-breakable, too.
  def indent
    content_tag(:span, "&nbsp;".html_safe, class: "ml-2")
  end

  def spacer
    content_tag(:span, "&nbsp;".html_safe, class: "mx-2")
  end

  # Return escaped HTML.
  #
  #   "<i>X</i>"  -->  "&lt;i&gt;X&lt;/i&gt;"
  def escape_html(html)
    h(html.to_str)
  end

  # Override Rails method of the same name.  Just calls our
  # Textile#textilize_without_paragraph method on the given string.
  def textilize_without_paragraph(str, do_object_links = false)
    Textile.textilize_without_paragraph(str, do_object_links)
  end

  # Override Rails method of the same name.  Just calls our Textile#textilize
  # method on the given string.
  def textilize(str, do_object_links = false)
    Textile.textilize(str, do_object_links)
  end

  # ----------------------------------------------------------------------------

  # This uses the fontawesome gem's `icon` helper! Can take class, id & args
  def safe_spinner(text = "", **args)
    space = text.present? ? " " : ""
    # Add the spin animation only if not present. Note cool string check:
    if args[:class].present?
      args[:class] += " fa-spin" unless args[:class]["fa-spin"]
    else
      args[:class] = "fa-spin"
    end
    [text, space, icon("fa-solid", "loader", args)].safe_join
  end

  def content_tag_if(condition, name, content_or_options_with_block = nil,
                     options = nil, escape = true, &block)
    return unless condition

    content_tag(name, content_or_options_with_block, options, escape, &block)
  end

  def content_tag_unless(condition, name, content_or_options_with_block = nil,
                         options = nil, escape = true, &block)
    content_tag_if(!condition, name, content_or_options_with_block,
                   options, escape, &block)
  end

  # Wrap an html object in '<span title="blah">' tag.  This has the effect of
  # giving it context help (mouse-over popup) in most modern browsers.
  #
  #   <%= add_context_help(link, "Click here to do something.") %>
  #
  def add_context_help(object, help)
    content_tag(:span, object, title: help, data: { toggle: "tooltip" })
  end

  # make a help-note styled element, like a div, p, or span
  def help_note(element = :span, string = "")
    content_tag(element, string, class: "help-note mr-3")
  end

  # make a form-text styled element, like a div, p
  def help_block(element = :div, string = "")
    content_tag(element, string, class: "form-text")
  end

  # draw a help block with an arrow
  def help_block_with_arrow(direction = nil, **args, &block)
    div_class = "card p-3 form-text position-relative"
    div_class += " mt-3" # if direction == "up"

    content_tag(:div, class: div_class,
                      id: args[:id]) do
      concat(capture(&block).to_s)
      if direction
        arrow_class = "arrow-#{direction}"
        arrow_class += " d-none d-md-block" unless args[:mobile]
        concat(content_tag(:div, "", class: arrow_class))
      end
    end
  end

  # unused
  def panel_with_outer_heading(**args, &block)
    html = []
    h_tag = (args[:h_tag].presence || :h4)
    html << content_tag(h_tag, args[:heading]) if args[:heading]
    html << card_block(**args, &block)
    safe_join(html)
  end

  def card_block(**args, &block)
    header = if args[:header].present?
               content_tag(:div, class: "card-header") do
                 args[:header]
               end
             else
               ""
             end
    footer = if args[:footer].present?
               content_tag(:div, class: "card-footer") do
                 args[:footer]
               end
             else
               ""
             end
    content_tag(
      :div,
      class: "card bg-light #{args[:class]}",
      id: args[:id]
    ) do
      [header,
       content_tag(:div, class: "card-body #{args[:inner_class]}") do
         concat(capture(&block).to_s)
       end,
       footer].safe_join
    end
  end

  def alert_block(level = :warning, string = "")
    content_tag(:div, string, class: "alert alert-#{level}")
  end
end

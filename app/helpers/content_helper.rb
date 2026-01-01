# frozen_string_literal: true

#  safe_br                      # <br/>,html_safe
#  safe_nbsp
#  indent
#  content_padded
#  escape_html                  # Return escaped HTML
#  safe_spinner

# helpers for content tags
module ContentHelper
  def safe_br
    "<br/>".html_safe
  end

  def safe_nbsp
    "&nbsp;".html_safe
  end

  # Create an in-line white-space element approximately the given width in
  # pixels.  It should be non-line-breakable, too.
  def indent
    tag.span("&nbsp;".html_safe, class: "ml-3")
  end

  def content_padded(**args, &block)
    content = block ? capture(&block).to_s : ""
    tag.div(
      class: class_names("p-3", args[:class]),
      **args.except(:class)
    ) do
      content
    end
  end

  # Return escaped HTML.
  #
  #   "<i>X</i>"  -->  "&lt;i&gt;X&lt;/i&gt;"
  def escape_html(html)
    h(html.to_str)
  end

  def safe_spinner(text = "")
    [
      text,
      tag.span("", class: "spinner-right mx-2")
    ].safe_join
  end
end

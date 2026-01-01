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

  # Override Rails method of the same name.  Just calls our
  # Textile#textilize_without_paragraph method on the given string.
  def textilize_without_paragraph(str, do_object_links = false)
    Textile.textilize_without_paragraph(str, do_object_links: do_object_links)
  end

  # Override Rails method of the same name.  Just calls our Textile#textilize
  # method on the given string.
  def textilize(str, do_object_links: false)
    Textile.textilize(str, do_object_links: do_object_links)
  end

  # ----------------------------------------------------------------------------

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
end

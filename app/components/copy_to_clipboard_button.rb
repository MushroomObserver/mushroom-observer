# frozen_string_literal: true

# Generic copy-to-clipboard icon button: a small `<button>` with a
# clipboard tooltip that copies `text:` when clicked. Unlike
# `Components::IdBadge` (which displays the value it copies), this
# button copies text that isn't necessarily rendered in the DOM —
# e.g. a DNA sequence's full bases, shown elsewhere on the page (or
# not shown at all).
class Components::CopyToClipboardButton < Components::Base
  prop :text, String
  prop :title, String
  prop :extra_class, _Nilable(String), default: nil

  def view_template
    button(
      type: "button",
      class: class_names("btn btn-default btn-xs", @extra_class),
      role: "button",
      aria: { label: @title },
      data: {
        toggle: "tooltip", placement: "bottom", title: @title,
        controller: "clipboard", clipboard_text_value: @text,
        action: "clipboard#copy", clipboard_copied_value: :COPIED.l
      }
    ) do
      span(class: "glyphicon glyphicon-copy", aria: { hidden: "true" })
    end
  end
end

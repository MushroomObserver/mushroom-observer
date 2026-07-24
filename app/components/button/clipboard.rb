# frozen_string_literal: true

# Icon button that copies `text:` to the clipboard via the Stimulus
# `clipboard` controller. `name:` becomes the tooltip label and sr-only
# accessible name (the icon is the visual; the name is never shown
# inline). Defaults to the copy icon, xs size, and link styling (btn-link
# resets native <button> chrome without adding visible framing); `.py-0`
# is always added since .btn-xs's own vertical padding otherwise sits
# the icon below the baseline of surrounding inline text — override any
# of these with the usual `Components::Button` kwargs.
#
# Bases aren't always displayed near the button (e.g. the sequences
# panel row shows only the locus), so copying from the model value
# directly avoids relying on rendered text in the DOM.
#
# @example Inline copy button for a DNA sequence
#   render(Components::Button::Clipboard.new(
#     text: @sequence.bases, name: :copy_this_sequence.ti
#   ))
class Components::Button::Clipboard < Components::Button
  def initialize(text:, name:, **rest)
    @text = text
    rest[:icon] ||= :copy
    rest[:size] ||= :xs
    rest[:variant] ||= :link
    caller_data = rest.delete(:data) || {}
    rest[:data] = tooltip_data(name).merge(clipboard_data).merge(caller_data)
    super(name: name, **rest)
  end

  private

  def merged_class
    class_names(super, "py-0")
  end

  def tooltip_data(name)
    { tooltip_target: "tip", placement: "bottom", title: name }
  end

  def clipboard_data
    {
      controller: "clipboard",
      clipboard_text_value: @text,
      action: "clipboard#copy",
      clipboard_copied_value: :copied.ti
    }
  end
end

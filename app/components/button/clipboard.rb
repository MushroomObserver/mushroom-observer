# frozen_string_literal: true

# Icon button that copies `text:` to the clipboard via the Stimulus
# `clipboard` controller. `name:` becomes the tooltip label and sr-only
# accessible name (the icon is the visual; the name is never shown
# inline). Defaults to the copy icon, xs size, and outline styling —
# override any of these with the usual `Components::Button` kwargs.
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
    rest[:variant] ||= :outline
    caller_data = rest.delete(:data) || {}
    rest[:data] = tooltip_data(name).merge(clipboard_data).merge(caller_data)
    super(name: name, **rest)
  end

  private

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

# frozen_string_literal: true

# Minimal padded-content wrapper: emits `<div class="p-3 ...">`
# around the block. Phlex-side drop-in for the legacy
# `ContentHelper#content_padded(**args)` ERB helper — all keyword
# args are forwarded to the underlying `<div>`, mirroring the
# helper's API. `class:` is composed with the default `"p-3"`.
#
# @example
#   render(Components::ContentPadded.new(id: "details")) do
#     p { plain("Field 1: ...") }
#   end
#
# @example with extra classes + data attrs
#   render(Components::ContentPadded.new(
#            class: "shadow-sm", data: { controller: "modal" }
#          )) { ... }
class Components::ContentPadded < Components::Base
  # @param attrs [Hash] HTML attrs forwarded verbatim to the `<div>`.
  #   `class:` is composed with the default `"p-3"`.
  def initialize(**attrs)
    super()
    @attrs = attrs
  end

  def view_template(&block)
    attrs = @attrs.dup
    attrs[:class] = class_names("p-3", attrs[:class])
    div(**attrs, &block)
  end
end

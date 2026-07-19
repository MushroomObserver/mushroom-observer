# frozen_string_literal: true

# Minimal padded-content wrapper: emits `<div class="p-3 ...">`
# around the block. All keyword args are forwarded to the
# underlying `<div>`; `class:` is composed with the default
# `"p-3"`.
#
# @example
#   ContentPadded(id: "details") do
#     p { plain("Field 1: ...") }
#   end
#
# @example with extra classes + data attrs
#   ContentPadded(
#     class: "shadow-sm", data: { controller: "modal" }
#   ) { ... }
class Components::ContentPadded < Components::Base
  # @param attrs [Hash] HTML attrs forwarded verbatim to the `<div>`.
  #   `class:` is composed with the default `"p-3"`.
  def initialize(**attrs)
    super()
    @attrs = attrs
  end

  def view_template(&block)
    div(**mix({ class: "p-3" }, @attrs), &block)
  end
end
